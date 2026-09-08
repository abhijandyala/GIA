import assert from "node:assert/strict";
import test from "node:test";

import {
  buildWeatherURL,
  createWeatherAPIProvider,
  forecastRequestWindow,
  mapWeatherResults,
  validateWeatherCriteria
} from "../src/providers/weatherapi-weather.mjs";

test("weather criteria map to bounded forecast and alert parameters", () => {
  const now = new Date("2027-06-10T08:00:00.000Z");
  const criteria = validateWeatherCriteria(validCriteria(), now);
  const window = forecastRequestWindow(criteria, now, 3);
  const url = buildWeatherURL(
    criteria,
    window.days,
    "weather-test-key"
  );

  assert.equal(url.hostname, "api.weatherapi.com");
  assert.equal(url.pathname, "/v1/forecast.json");
  assert.equal(url.searchParams.get("q"), "38.7223,-9.1393");
  assert.equal(url.searchParams.get("days"), "3");
  assert.equal(url.searchParams.get("alerts"), "yes");
  assert.equal(url.searchParams.get("aqi"), "no");
  assert.equal(url.searchParams.get("key"), "weather-test-key");
});

test("distant trips do not consume forecast API quota", async () => {
  const criteria = validCriteria();
  criteria.dateRange.start = "2027-07-10T00:00:00.000Z";
  criteria.dateRange.end = "2027-07-17T00:00:00.000Z";
  let called = false;
  const provider = createWeatherAPIProvider({
    apiKey: "weather-key",
    forecastDaysLimit: 3,
    fetchImplementation: async () => {
      called = true;
      return Response.json(weatherFixture());
    },
    now: () => new Date("2027-06-10T08:00:00.000Z")
  });
  const result = await provider(criteria);

  assert.deepEqual(result.snapshots, []);
  assert.equal(called, false);
});

test("hourly conditions and government alerts map with provenance", () => {
  const now = new Date("2027-06-10T08:00:00.000Z");
  const criteria = validateWeatherCriteria(validCriteria(), now);
  const snapshots = mapWeatherResults(
    weatherFixture(),
    criteria,
    now
  );

  assert.equal(snapshots.length, 1);
  const snapshot = snapshots[0];
  assert.equal(snapshot.timeZoneIdentifier, "Europe/Lisbon");
  assert.equal(snapshot.periods.length, 3);
  assert.equal(snapshot.periods[0].condition, "clear");
  assert.equal(snapshot.periods[0].temperatureCelsius, 23);
  assert.equal(snapshot.periods[1].condition, "rain");
  assert.equal(snapshot.periods[1].precipitationProbability, 0.75);
  assert.equal(snapshot.periods[2].condition, "storm");
  assert.equal(snapshot.alerts.length, 1);
  assert.equal(snapshot.alerts[0].severity, "severe");
  assert.equal(snapshot.alerts[0].reportingAgency, "IPMA");
  assert.match(snapshot.alerts[0].sourceURL, /^https:/);
  assert.equal(snapshot.provenance.provider, "weatherapi");
  assert.equal(
    snapshot.provenance.expiresAt,
    "2027-06-10T08:15:00.000Z"
  );
  assert.equal(
    snapshot.provenance.sourceURL.includes("weather-test-key"),
    false
  );
});

test("alerts are omitted when not requested", () => {
  const now = new Date("2027-06-10T08:00:00.000Z");
  const criteriaInput = validCriteria();
  criteriaInput.includeAlerts = false;
  const criteria = validateWeatherCriteria(criteriaInput, now);
  const snapshots = mapWeatherResults(
    weatherFixture(),
    criteria,
    now
  );

  assert.equal(snapshots.length, 1);
  assert.deepEqual(snapshots[0].alerts, []);
});

test("missing optional weather values remain unknown", () => {
  const payload = weatherFixture();
  const hour = payload.forecast.forecastday[0].hour[0];
  hour.temp_c = null;
  hour.feelslike_c = null;
  hour.wind_kph = null;
  delete hour.chance_of_rain;
  delete hour.chance_of_snow;

  const now = new Date("2027-06-10T08:00:00.000Z");
  const snapshots = mapWeatherResults(
    payload,
    validateWeatherCriteria(validCriteria(), now),
    now
  );
  const mapped = snapshots[0].periods[0];

  assert.equal(mapped.temperatureCelsius, null);
  assert.equal(mapped.feelsLikeCelsius, null);
  assert.equal(mapped.windKilometersPerHour, null);
  assert.equal(mapped.precipitationProbability, null);
});

test("past, reversed, and coordinate-invalid requests fail preflight", async () => {
  const now = new Date("2027-06-10T08:00:00.000Z");
  const past = validCriteria();
  past.dateRange.start = "2027-05-01T00:00:00.000Z";
  past.dateRange.end = "2027-05-03T00:00:00.000Z";
  const reversed = validCriteria();
  reversed.dateRange.end = "2027-06-01T00:00:00.000Z";
  const invalidCoordinate = validCriteria();
  invalidCoordinate.location.coordinate.latitude = 100;
  let called = false;
  const provider = createWeatherAPIProvider({
    apiKey: "weather-key",
    fetchImplementation: async () => {
      called = true;
      return Response.json(weatherFixture());
    },
    now: () => now
  });

  await assert.rejects(
    () => provider(past),
    (error) => error.code === "past_weather_trip"
  );
  await assert.rejects(
    () => provider(reversed),
    (error) => error.code === "reversed_weather_dates"
  );
  await assert.rejects(
    () => provider(invalidCoordinate),
    (error) => error.code === "missing_weather_coordinate"
  );
  assert.equal(called, false);
});

test("missing forecast data differs from a valid empty date filter", () => {
  const now = new Date("2027-06-10T08:00:00.000Z");
  const criteria = validateWeatherCriteria(validCriteria(), now);

  assert.throws(
    () => mapWeatherResults(
      {
        location: {
          name: "Lisbon",
          lat: 38.7223,
          lon: -9.1393,
          tz_id: "Europe/Lisbon"
        }
      },
      criteria,
      now
    ),
    (error) => error.code === "weatherapi_missing_forecast"
  );
});

test("weather adapter sanitizes authorization failure", async () => {
  const provider = createWeatherAPIProvider({
    apiKey: "invalid-key",
    fetchImplementation: async () => Response.json(
      {
        error: {
          message: "sensitive account details"
        }
      },
      {
        status: 403
      }
    ),
    now: () => new Date("2027-06-10T08:00:00.000Z")
  });

  await assert.rejects(
    () => provider(validCriteria()),
    (error) => (
      error.status === 503
      && error.code === "weatherapi_authorization_failed"
      && !error.message.includes("sensitive")
    )
  );
});

test("missing weather configuration fails closed", async () => {
  const provider = createWeatherAPIProvider({
    apiKey: ""
  });

  await assert.rejects(
    () => provider(validCriteria()),
    (error) => (
      error.status === 503
      && error.code === "weatherapi_not_configured"
    )
  );
});

function validCriteria() {
  return {
    location: {
      id: "lisbon-id",
      name: "Lisbon",
      city: "Lisbon",
      country: "Portugal",
      countryCode: "PT",
      coordinate: {
        latitude: 38.7223,
        longitude: -9.1393
      },
      timeZoneIdentifier: "Europe/Lisbon"
    },
    dateRange: {
      start: "2027-06-10T00:00:00.000Z",
      end: "2027-06-12T00:00:00.000Z",
      timeZoneIdentifier: "Europe/Lisbon"
    },
    includeAlerts: true
  };
}

function weatherFixture() {
  const alert = {
    headline: "Severe thunderstorm warning",
    sender_name: "IPMA",
    severity: "Severe",
    effective: "2027-06-10T11:00:00.000Z",
    expires: "2027-06-10T18:00:00.000Z",
    instruction: "Move indoors.",
    uri: "https://alerts.example/severe"
  };

  return {
    location: {
      name: "Lisbon",
      region: "Lisbon",
      country: "Portugal",
      lat: 38.7223,
      lon: -9.1393,
      tz_id: "Europe/Lisbon"
    },
    forecast: {
      forecastday: [
        {
          date: "2027-06-10",
          hour: [
            weatherHour(
              "2027-06-10T09:00:00.000Z",
              "Sunny",
              1000,
              10
            ),
            weatherHour(
              "2027-06-10T14:00:00.000Z",
              "Heavy rain",
              1195,
              75
            ),
            weatherHour(
              "2027-06-10T17:00:00.000Z",
              "Thunderstorm",
              1276,
              90
            )
          ]
        }
      ]
    },
    alerts: {
      alert: [
        alert,
        {
          ...alert
        },
        {
          headline: "Expired advisory",
          severity: "Minor",
          expires: "2027-06-10T07:00:00.000Z"
        }
      ]
    }
  };
}

function weatherHour(isoDate, text, code, rainChance) {
  return {
    time_epoch: Date.parse(isoDate) / 1000,
    temp_c: 23,
    feelslike_c: 24,
    condition: {
      text,
      code
    },
    chance_of_rain: rainChance,
    chance_of_snow: 0,
    wind_kph: 18
  };
}
