export const PLAN_BLUEPRINT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: {
      type: "string",
      minLength: 1,
      maxLength: 80
    },
    summary: {
      type: "string",
      minLength: 1,
      maxLength: 500
    },
    selectedFlightOfferIDs: {
      type: "array",
      maxItems: 8,
      items: {
        type: "string"
      }
    },
    selectedHotelOfferIDs: {
      type: "array",
      maxItems: 8,
      items: {
        type: "string"
      }
    },
    days: {
      type: "array",
      maxItems: 90,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          date: {
            type: "string",
            minLength: 10,
            maxLength: 10
          },
          timeZoneIdentifier: {
            type: "string",
            minLength: 1,
            maxLength: 80
          },
          items: {
            type: "array",
            maxItems: 30,
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                sourceKind: {
                  type: "string",
                  enum: [
                    "flight",
                    "hotel",
                    "place",
                    "event",
                    "route",
                    "free_time"
                  ]
                },
                sourceIdentifier: {
                  type: ["string", "null"]
                },
                start: {
                  type: "string",
                  minLength: 20,
                  maxLength: 40
                },
                end: {
                  type: "string",
                  minLength: 20,
                  maxLength: 40
                },
                rationale: {
                  type: "string",
                  minLength: 1,
                  maxLength: 300
                }
              },
              required: [
                "sourceKind",
                "sourceIdentifier",
                "start",
                "end",
                "rationale"
              ]
            }
          }
        },
        required: [
          "date",
          "timeZoneIdentifier",
          "items"
        ]
      }
    },
    recommendationRationales: {
      type: "array",
      maxItems: 40,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          sourceKind: {
            type: "string",
            enum: ["flight", "hotel", "place", "event", "route"]
          },
          sourceIdentifier: {
            type: "string"
          },
          reasons: {
            type: "array",
            minItems: 1,
            maxItems: 5,
            items: {
              type: "string",
              minLength: 1,
              maxLength: 180
            }
          }
        },
        required: [
          "sourceKind",
          "sourceIdentifier",
          "reasons"
        ]
      }
    },
    warnings: {
      type: "array",
      maxItems: 20,
      items: {
        type: "string",
        minLength: 1,
        maxLength: 240
      }
    }
  },
  required: [
    "title",
    "summary",
    "selectedFlightOfferIDs",
    "selectedHotelOfferIDs",
    "days",
    "recommendationRationales",
    "warnings"
  ]
};

export class PlanValidationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PlanValidationError";
    this.code = code;
  }
}

export function validatePlanningInput(input) {
  requireObject(input, "invalid_planning_input");
  requireObject(input.request, "missing_trip_request");
  requireArray(input.flightOffers, "missing_flight_offers", 40);
  requireArray(input.hotelOffers, "missing_hotel_offers", 40);
  requireArray(input.places, "missing_places", 80);
  requireArray(input.events ?? [], "missing_events", 80);
  requireArray(input.routes, "missing_routes", 120);
  requireArray(input.weather, "missing_weather", 40);

  if (!input.request.dateRange) {
    throw new PlanValidationError(
      "missing_trip_dates",
      "Validated travel dates are required before planning."
    );
  }
  if (
    !Array.isArray(input.request.destinations)
    || input.request.destinations.length === 0
  ) {
    throw new PlanValidationError(
      "missing_destination",
      "A validated destination is required before planning."
    );
  }
  if (
    !Number.isInteger(input.request.travelerCount)
    || input.request.travelerCount < 1
  ) {
    throw new PlanValidationError(
      "missing_travelers",
      "A valid traveler count is required before planning."
    );
  }
  if (
    input.request.totalBudget
    && Number(input.request.totalBudget.amount) <= 0
  ) {
    throw new PlanValidationError(
      "invalid_budget",
      "A supplied budget must be greater than zero."
    );
  }

  for (const collection of [
    input.flightOffers,
    input.hotelOffers,
    input.places,
    input.events ?? [],
    input.routes
  ]) {
    for (const item of collection) {
      requireObject(item, "invalid_source_item");
      requireString(item.id, "missing_source_id");
    }
  }

  return input;
}

export function plannerContext(input) {
  validatePlanningInput(input);

  return {
    request: {
      origin: summarizeLocation(input.request.origin),
      destinations: input.request.destinations.map(summarizeLocation),
      dateRange: input.request.dateRange,
      durationDays: input.request.durationDays,
      travelerCount: input.request.travelerCount,
      totalBudget: input.request.totalBudget,
      interests: input.request.interests ?? [],
      dietaryRequirements:
        input.request.dietaryRequirements ?? [],
      accessibilityRequirements:
        input.request.accessibilityRequirements ?? [],
      preferredPace: input.request.preferredPace,
      flightPreferences: input.request.flightPreferences,
      hotelPreferences: input.request.hotelPreferences
    },
    flightOffers: input.flightOffers.map((offer) => ({
      id: offer.id,
      outboundSegments: offer.outboundSegments,
      returnSegments: offer.returnSegments,
      totalDuration: offer.totalDuration,
      totalPrice: offer.totalPrice,
      baggage: offer.baggage,
      badges: offer.badges,
      carbonEmissionsGrams: offer.carbonEmissionsGrams,
      priceInsight: offer.priceInsight,
      refundable: offer.refundable
    })),
    hotelOffers: input.hotelOffers.map((offer) => ({
      id: offer.id,
      name: offer.name,
      location: summarizeLocation(offer.location),
      lodgingType: offer.lodgingType,
      starRating: offer.starRating,
      guestRating: offer.guestRating,
      reviewCount: offer.reviewCount,
      nightlyPrice: offer.nightlyPrice,
      totalPrice: offer.totalPrice,
      taxesAndFeesIncluded: offer.taxesAndFeesIncluded,
      roomDescription: offer.roomDescription,
      amenities: offer.amenities,
      cancellationPolicy: offer.cancellationPolicy
    })),
    places: input.places.map((place) => ({
      id: place.id,
      name: place.name,
      location: summarizeLocation(place.location),
      categories: place.categories,
      rating: place.rating,
      reviewCount: place.reviewCount,
      estimatedCostPerTraveler: place.estimatedCostPerTraveler,
      estimatedDuration: place.estimatedDuration,
      openingHours: place.openingHours,
      dietaryOptions: place.dietaryOptions,
      accessibilityFeatures: place.accessibilityFeatures,
      indoor: place.indoor,
      reservationRequired: place.reservationRequired
    })),
    events: (input.events ?? []).map((event) => ({
      id: event.id,
      title: event.title,
      summary: event.summary,
      venueName: event.venueName,
      location: summarizeLocation(event.location),
      start: event.start,
      end: event.end,
      rawDateText: event.rawDateText,
      timeZoneIdentifier: event.timeZoneIdentifier,
      timeZoneIsResolved: event.timeZoneIsResolved,
      status: event.status,
      schedulingTraits: event.schedulingTraits
    })),
    routes: input.routes.map((route) => ({
      id: route.id,
      origin: summarizeLocation(route.origin),
      destination: summarizeLocation(route.destination),
      mode: route.mode,
      plannedDeparture: route.plannedDeparture,
      plannedArrival: route.plannedArrival,
      duration: route.duration,
      distanceMeters: route.distanceMeters,
      estimatedCost: route.estimatedCost,
      bufferDuration: route.bufferDuration,
      confidence: route.confidence
    })),
    weather: input.weather.map((snapshot) => ({
      id: snapshot.id,
      location: summarizeLocation(snapshot.location),
      timeZoneIdentifier: snapshot.timeZoneIdentifier,
      periods: snapshot.periods,
      alerts: snapshot.alerts
    }))
  };
}

export function validateAndSanitizeBlueprint(blueprint, input) {
  validatePlanningInput(input);
  requireExactObject(
    blueprint,
    [
      "title",
      "summary",
      "selectedFlightOfferIDs",
      "selectedHotelOfferIDs",
      "days",
      "recommendationRationales",
      "warnings"
    ],
    "invalid_plan_blueprint"
  );
  requireBoundedString(blueprint.title, 1, 80, "invalid_plan_title");
  requireBoundedString(
    blueprint.summary,
    1,
    500,
    "invalid_plan_summary"
  );
  requireArray(
    blueprint.selectedFlightOfferIDs,
    "invalid_flight_selections",
    8
  );
  requireArray(
    blueprint.selectedHotelOfferIDs,
    "invalid_hotel_selections",
    8
  );
  requireArray(blueprint.days, "invalid_plan_days", 90);
  requireArray(
    blueprint.recommendationRationales,
    "invalid_recommendations",
    40
  );
  requireArray(blueprint.warnings, "invalid_plan_warnings", 20);

  const indexes = sourceIndexes(input);
  validateSelectedIDs(
    blueprint.selectedFlightOfferIDs,
    indexes.flight,
    "unknown_flight_selection"
  );
  validateSelectedIDs(
    blueprint.selectedHotelOfferIDs,
    indexes.hotel,
    "unknown_hotel_selection"
  );

  const rangeStart = parseDate(
    input.request.dateRange.start,
    "invalid_request_start"
  );
  const rangeEnd = parseDate(
    input.request.dateRange.end,
    "invalid_request_end"
  );
  const finalBoundary = new Date(
    rangeEnd.getTime() + 86_400_000
  );

  const days = blueprint.days.map((day, dayIndex) => {
    requireExactObject(
      day,
      ["date", "timeZoneIdentifier", "items"],
      "invalid_plan_day"
    );
    requireDateOnly(day.date, "invalid_plan_day_date");
    requireBoundedString(
      day.timeZoneIdentifier,
      1,
      80,
      "invalid_time_zone"
    );
    requireArray(day.items, "invalid_plan_items", 30);

    const items = day.items.map((item, itemIndex) => {
      requireExactObject(
        item,
        [
          "sourceKind",
          "sourceIdentifier",
          "start",
          "end",
          "rationale"
        ],
        "invalid_plan_item"
      );
      if (
        !["flight", "hotel", "place", "event", "route", "free_time"]
          .includes(item.sourceKind)
      ) {
        throw new PlanValidationError(
          "invalid_source_kind",
          "The plan used an unsupported source kind."
        );
      }
      requireBoundedString(
        item.rationale,
        1,
        300,
        "invalid_item_rationale"
      );

      const start = parseDate(item.start, "invalid_item_start");
      const end = parseDate(item.end, "invalid_item_end");
      if (end < start) {
        throw new PlanValidationError(
          "reversed_item_time",
          `Day ${dayIndex + 1}, item ${itemIndex + 1} ends before it starts.`
        );
      }
      if (start < rangeStart || end > finalBoundary) {
        throw new PlanValidationError(
          "item_outside_trip",
          "The plan scheduled an item outside the trip dates."
        );
      }

      validateSourceReference(
        item.sourceKind,
        item.sourceIdentifier,
        indexes
      );

      return {
        sourceKind: item.sourceKind,
        sourceIdentifier: item.sourceIdentifier,
        start: start.toISOString(),
        end: end.toISOString(),
        rationale: item.rationale
      };
    });

    const chronologicalItems = [...items].sort(
      (left, right) => (
        Date.parse(left.start) - Date.parse(right.start)
      )
    );
    for (let index = 1; index < chronologicalItems.length; index += 1) {
      if (
        Date.parse(chronologicalItems[index].start)
        < Date.parse(chronologicalItems[index - 1].end)
      ) {
        throw new PlanValidationError(
          "overlapping_items",
          "The plan contains overlapping itinerary items."
        );
      }
    }

    return {
      date: day.date,
      timeZoneIdentifier: day.timeZoneIdentifier,
      items
    };
  });

  const recommendationRationales =
    blueprint.recommendationRationales.map((recommendation) => {
      requireExactObject(
        recommendation,
        ["sourceKind", "sourceIdentifier", "reasons"],
        "invalid_recommendation"
      );
      if (
        !["flight", "hotel", "place", "event", "route"]
          .includes(recommendation.sourceKind)
      ) {
        throw new PlanValidationError(
          "invalid_recommendation_kind",
          "A recommendation used an unsupported source kind."
        );
      }
      validateSourceReference(
        recommendation.sourceKind,
        recommendation.sourceIdentifier,
        indexes
      );
      requireArray(
        recommendation.reasons,
        "invalid_recommendation_reasons",
        5,
        1
      );
      const reasons = recommendation.reasons.map((reason) => {
        requireBoundedString(
          reason,
          1,
          180,
          "invalid_recommendation_reason"
        );
        return reason;
      });

      return {
        sourceKind: recommendation.sourceKind,
        sourceIdentifier: recommendation.sourceIdentifier,
        reasons
      };
    });

  const warnings = blueprint.warnings.map((warning) => {
    requireBoundedString(
      warning,
      1,
      240,
      "invalid_plan_warning"
    );
    return warning;
  });

  return {
    title: blueprint.title,
    summary: blueprint.summary,
    selectedFlightOfferIDs: unique(
      blueprint.selectedFlightOfferIDs
    ),
    selectedHotelOfferIDs: unique(
      blueprint.selectedHotelOfferIDs
    ),
    days,
    recommendationRationales,
    warnings
  };
}

function sourceIndexes(input) {
  return {
    flight: new Set(input.flightOffers.map((item) => item.id)),
    hotel: new Set(input.hotelOffers.map((item) => item.id)),
    place: new Set(input.places.map((item) => item.id)),
    event: new Set((input.events ?? []).map((item) => item.id)),
    route: new Set(input.routes.map((item) => item.id))
  };
}

function validateSelectedIDs(values, allowed, code) {
  for (const value of values) {
    requireString(value, code);
    if (!allowed.has(value)) {
      throw new PlanValidationError(
        code,
        "The plan selected an unknown sourced option."
      );
    }
  }
}

function validateSourceReference(kind, identifier, indexes) {
  if (kind === "free_time") {
    if (identifier !== null) {
      throw new PlanValidationError(
        "unexpected_free_time_source",
        "Free time cannot reference provider data."
      );
    }
    return;
  }

  requireString(identifier, "missing_source_identifier");
  if (!indexes[kind]?.has(identifier)) {
    throw new PlanValidationError(
      "unknown_source_identifier",
      "The plan referenced an unknown sourced option."
    );
  }
}

function summarizeLocation(location) {
  if (!location) {
    return null;
  }
  return {
    id: location.id,
    name: location.name,
    city: location.city,
    region: location.region,
    country: location.country,
    countryCode: location.countryCode,
    iataCode: location.iataCode,
    coordinate: location.coordinate,
    timeZoneIdentifier: location.timeZoneIdentifier
  };
}

function requireObject(value, code) {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new PlanValidationError(code, "Expected an object.");
  }
}

function requireExactObject(value, keys, code) {
  requireObject(value, code);
  const actualKeys = Object.keys(value).sort();
  const expectedKeys = [...keys].sort();
  if (JSON.stringify(actualKeys) !== JSON.stringify(expectedKeys)) {
    throw new PlanValidationError(
      code,
      "The object did not match the required schema."
    );
  }
}

function requireArray(value, code, maximum, minimum = 0) {
  if (
    !Array.isArray(value)
    || value.length < minimum
    || value.length > maximum
  ) {
    throw new PlanValidationError(
      code,
      "Expected a bounded array."
    );
  }
}

function requireString(value, code) {
  if (typeof value !== "string" || value.length === 0) {
    throw new PlanValidationError(code, "Expected a string.");
  }
}

function requireBoundedString(value, minimum, maximum, code) {
  if (
    typeof value !== "string"
    || value.length < minimum
    || value.length > maximum
  ) {
    throw new PlanValidationError(
      code,
      "Expected a bounded string."
    );
  }
}

function requireDateOnly(value, code) {
  if (
    typeof value !== "string"
    || !/^\d{4}-\d{2}-\d{2}$/.test(value)
  ) {
    throw new PlanValidationError(
      code,
      "Expected an ISO calendar date."
    );
  }

  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (
    Number.isNaN(parsed.getTime())
    || parsed.toISOString().slice(0, 10) !== value
  ) {
    throw new PlanValidationError(
      code,
      "Expected a valid ISO calendar date."
    );
  }
}

function parseDate(value, code) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new PlanValidationError(
      code,
      "Expected an ISO date and time."
    );
  }
  return date;
}

function unique(values) {
  return [...new Set(values)];
}
