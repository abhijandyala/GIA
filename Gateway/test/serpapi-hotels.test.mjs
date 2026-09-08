import assert from "node:assert/strict";
import test from "node:test";

import {
  buildHotelSearchURL,
  createSerpApiHotelSearch,
  mapHotelResults,
  validateHotelCriteria
} from "../src/providers/serpapi-hotels.mjs";

test("hotel criteria map to documented SerpApi parameters", () => {
  const criteria = validateHotelCriteria(validCriteria());
  const url = buildHotelSearchURL(criteria, "test-serp-key");

  assert.equal(url.searchParams.get("engine"), "google_hotels");
  assert.equal(url.searchParams.get("q"), "Lisbon");
  assert.equal(url.searchParams.get("check_in_date"), "2027-06-10");
  assert.equal(url.searchParams.get("check_out_date"), "2027-06-17");
  assert.equal(url.searchParams.get("adults"), "4");
  assert.equal(url.searchParams.get("rooms"), "2");
  assert.equal(url.searchParams.get("currency"), "USD");
  assert.equal(url.searchParams.get("sort_by"), "3");
  assert.equal(url.searchParams.get("hotel_class"), "4,5");
  assert.equal(url.searchParams.get("rating"), "9");
  assert.equal(url.searchParams.get("free_cancellation"), "true");
  assert.equal(url.searchParams.get("max_price"), "250");
});

test("hotel properties map to stable source-grounded offers", () => {
  const criteria = validateHotelCriteria(validCriteria());
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");
  const first = mapHotelResults(
    serpApiFixture(),
    criteria,
    retrievedAt
  );
  const second = mapHotelResults(
    serpApiFixture(),
    criteria,
    new Date("2026-09-06T09:00:00.000Z")
  );

  assert.equal(first.length, 2);
  assert.equal(first[0].id, second[0].id);
  assert.equal(first[0].name, "Lisbon Riverside Hotel");
  assert.equal(first[0].starRating, 4);
  assert.equal(first[0].guestRating, 4.7);
  assert.equal(first[0].guestRatingScale, 5);
  assert.equal(first[0].reviewCount, 421);
  assert.equal(first[0].nightlyPrice.amount, 200);
  assert.equal(first[0].totalPrice.amount, 1400);
  assert.equal(first[0].taxesAndFeesIncluded, true);
  assert.ok(first[0].amenities.includes("wifi"));
  assert.ok(first[0].amenities.includes("breakfast"));
  assert.ok(first[0].amenities.includes("accessibleRoom"));
  assert.equal(first[0].imageURLs.length, 2);
  assert.ok(first[0].badges.includes("flexible"));
  assert.equal(first[0].badges.includes("giaRecommended"), false);
  assert.equal(first[0].location.coordinate.latitude, 38.7223);
  assert.equal(first[0].provenance.provider, "serpapi");
  assert.equal(
    first[0].provenance.expiresAt,
    "2026-09-06T08:05:00.000Z"
  );

  assert.equal(first[1].nightlyPrice.amount, 150);
  assert.equal(first[1].totalPrice.amount, 1050);
  assert.ok(first[1].badges.includes("lowestPrice"));
});

test("required amenities filter otherwise usable hotels", () => {
  const criteriaInput = validCriteria();
  criteriaInput.preferences.requiredAmenities = [
    "wifi",
    "airportShuttle"
  ];
  const criteria = validateHotelCriteria(criteriaInput);
  const offers = mapHotelResults(
    serpApiFixture(),
    criteria,
    new Date("2026-09-06T08:00:00.000Z")
  );

  assert.equal(offers.length, 0);
});

test("client constraints are rechecked after provider mapping", () => {
  const payload = serpApiFixture();
  payload.properties[0].rate_per_night.extracted_lowest = 400;
  payload.properties[0].overall_rating = 3.8;
  const offers = mapHotelResults(
    payload,
    validateHotelCriteria(validCriteria()),
    new Date("2026-09-06T08:00:00.000Z")
  );

  assert.equal(offers.length, 1);
  assert.equal(offers[0].name, "Lisbon Garden Stay");
});

test("empty hotel searches differ from malformed properties", () => {
  const criteria = validateHotelCriteria(validCriteria());
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");

  assert.deepEqual(
    mapHotelResults({}, criteria, retrievedAt),
    []
  );
  assert.throws(
    () => mapHotelResults(
      {
        properties: [
          {
            name: "Missing Price",
            property_token: "bad-property"
          }
        ]
      },
      criteria,
      retrievedAt
    ),
    (error) => error.code === "serpapi_unusable_hotel_results"
  );
});

test("invalid hotel dates and ratings fail before provider calls", async () => {
  const invalidDates = validCriteria();
  invalidDates.checkOutDate = invalidDates.checkInDate;
  const invalidRating = validCriteria();
  invalidRating.preferences.minimumGuestRating = 9;
  let called = false;
  const search = createSerpApiHotelSearch({
    apiKey: "test-key",
    fetchImplementation: async () => {
      called = true;
      return Response.json(serpApiFixture());
    }
  });

  await assert.rejects(
    () => search(invalidDates),
    (error) => error.code === "invalid_hotel_date_range"
  );
  await assert.rejects(
    () => search(invalidRating),
    (error) => error.code === "invalid_guest_rating"
  );
  assert.equal(called, false);
});

test("hotel adapter sanitizes provider authorization failure", async () => {
  const search = createSerpApiHotelSearch({
    apiKey: "invalid-key",
    fetchImplementation: async () => Response.json(
      {
        error: "sensitive account details"
      },
      {
        status: 403
      }
    )
  });

  await assert.rejects(
    () => search(validCriteria()),
    (error) => (
      error.status === 503
      && error.code === "serpapi_authorization_failed"
      && !error.message.includes("sensitive")
    )
  );
});

test("missing hotel configuration fails closed", async () => {
  const search = createSerpApiHotelSearch({
    apiKey: "",
    fetchImplementation: async () => {
      throw new Error("must not run");
    }
  });

  await assert.rejects(
    () => search(validCriteria()),
    (error) => (
      error.status === 503
      && error.code === "serpapi_not_configured"
    )
  );
});

function validCriteria() {
  return {
    destination: {
      id: "destination-id",
      name: "Lisbon",
      city: "Lisbon",
      country: "Portugal",
      countryCode: "PT",
      timeZoneIdentifier: "Europe/Lisbon"
    },
    checkInDate: "2027-06-10T00:00:00.000Z",
    checkOutDate: "2027-06-17T00:00:00.000Z",
    adults: 4,
    rooms: 2,
    currencyCode: "usd",
    preferences: {
      allowedTypes: ["hotel"],
      minimumStarRating: 4,
      minimumGuestRating: 4.5,
      requiredAmenities: ["wifi", "breakfast"],
      maximumNightlyRate: {
        amount: 250,
        currencyCode: "USD"
      },
      refundablePreferred: true,
      maximumMinutesFromActivities: 30
    }
  };
}

function serpApiFixture() {
  return {
    search_metadata: {
      google_hotels_url:
        "https://www.google.com/travel/search?q=Lisbon"
    },
    properties: [
      {
        type: "hotel",
        name: "Lisbon Riverside Hotel",
        description: "Modern rooms near central Lisbon.",
        link: "https://hotel.example/book",
        gps_coordinates: {
          latitude: 38.7223,
          longitude: -9.1393
        },
        check_in_time: "3:00 PM",
        check_out_time: "11:00 AM",
        rate_per_night: {
          lowest: "$200",
          extracted_lowest: 200,
          before_taxes_fees: "$170",
          extracted_before_taxes_fees: 170
        },
        total_rate: {
          lowest: "$1,400",
          extracted_lowest: 1400,
          before_taxes_fees: "$1,190",
          extracted_before_taxes_fees: 1190
        },
        extracted_hotel_class: 4,
        overall_rating: 4.7,
        reviews: 421,
        amenities: [
          "Free Wi-Fi",
          "Free breakfast",
          "Wheelchair accessible"
        ],
        free_cancellation: true,
        thumbnail: "https://images.example/hotel-thumb.jpg",
        images: [
          {
            original_image:
              "https://images.example/hotel-original.jpg"
          }
        ],
        property_token: "riverside-token"
      },
      {
        type: "hotel",
        name: "Lisbon Garden Stay",
        link: "https://garden.example/book",
        gps_coordinates: {
          latitude: 38.71,
          longitude: -9.14
        },
        rate_per_night: {
          lowest: "$150",
          extracted_lowest: 150
        },
        hotel_class: "4-star hotel",
        overall_rating: 4.6,
        reviews: 210,
        amenities: [
          "WiFi",
          "Breakfast"
        ],
        property_token: "garden-token"
      }
    ]
  };
}
