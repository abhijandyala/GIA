# G.I.A. Phase 1 Test Record

## Conversation Regression Suite

The shared `GIA` scheme includes the `GIAUnitTests` target. Run Product > Test
in Xcode, or use `xcodebuild test` with an iPhone Simulator destination. The
suite uses local mocks and bundled demo fixtures only; it never calls a live
provider or performs a real booking.

Coverage includes missing information, multi-part answers, answer changes,
repeated questions, date phrasing, budgets, group sizes, provider failure,
empty results, itinerary assembly, simulated booking confirmation, and the
spoken-question transition back to active recognition. See
`Documentation/BUG_LOG_2026-09-08.md` for failure modes and remaining physical-
device checks.

## Supported Environment

- Device family: iPhone
- Orientation: portrait
- Minimum operating system: iOS 17
- Appearance: dark
- Network requirement: optional for voice recognition; visual/manual fallback
  remains available offline

Desktop displays, macOS, Mac Catalyst, browser viewports, landscape layout, and
iPad-specific layouts are outside Phase 1.

## Functional Verification

### Launch

- [ ] A clean launch opens Map.
- [ ] Map is visibly selected in bottom navigation.
- [ ] `SPACE` appears at top-left.
- [ ] `GIA` appears at the exact horizontal center.
- [ ] The hamburger appears at top-right.
- [ ] Earth appears near the visual center.
- [ ] First launch requests microphone and speech access with clear purpose text.
- [ ] Later launches do not repeat granted permission prompts.
- [ ] Core Map and manual transition remain available without network.

### Menu

- [ ] First hamburger tap opens the anchored dropdown.
- [ ] Second hamburger tap closes it.
- [ ] Tapping outside closes it.
- [ ] The panel is visibly present but contains no menu options.
- [ ] The panel remains inside the iPhone safe area.
- [ ] Opening the menu does not interrupt Earth rendering.
- [ ] Changing tabs closes the menu.

### Navigation

- [ ] Plan remains blank when no request exists.
- [ ] A validated spoken request automatically selects Plan.
- [ ] Plan displays the exact captured request.
- [ ] The active GIA circle contracts into the Plan indicator.
- [ ] Group opens a blank screen.
- [ ] Bottom navigation remains visible on every destination.
- [ ] The selected destination is visually and accessibly identified.
- [ ] Returning to Map restores the existing Earth scene.
- [ ] Earth orientation does not reset during ordinary tab switching.
- [ ] Rapid tab switching does not duplicate SceneKit nodes or views.

### Earth

- [ ] Earth is dimensional under scene lighting.
- [ ] Earth rotates slowly and continuously while Map is active.
- [ ] No drag, zoom, orbit, or other globe gesture is enabled.
- [ ] Earth pauses on Plan and Group.
- [ ] Earth pauses while the app is inactive or backgrounded.
- [ ] Earth resumes when Map becomes active.
- [ ] Reduce Motion stops continuous rotation.
- [ ] Earth texture loads from the application bundle in airplane mode.
- [ ] No texture seam, missing material, or obvious geometric edge is visible.

## Accessibility Verification

- [ ] Plan, Map, and Group have correct VoiceOver labels.
- [ ] The selected tab exposes the selected trait.
- [ ] Hamburger is labeled “Menu.”
- [ ] Hamburger exposes expanded/collapsed state.
- [ ] Empty menu content does not create meaningless focus stops.
- [ ] Interactive targets are at least 44 by 44 points.
- [ ] Selection is not communicated by color alone.
- [ ] Accessibility text sizes do not move `GIA` away from screen center.
- [ ] Increased Contrast preserves visual hierarchy.
- [ ] Reduce Transparency does not make the menu unreadable.
- [ ] Reduce Motion behavior is correct.

## Portrait iPhone Layout Matrix

Test representative physical or simulated devices in portrait:

- [ ] Compact-width iPhone with the smallest supported display
- [ ] Standard-size iPhone
- [ ] Large/Pro Max iPhone
- [ ] iPhone with Dynamic Island

For each device:

- [ ] Top controls clear the status area.
- [ ] `GIA` is geometrically centered.
- [ ] Earth remains visually centered and does not collide with navigation.
- [ ] Bottom navigation clears the home indicator.
- [ ] Dropdown remains fully visible.
- [ ] No text truncates.

## Reliability and Presentation Verification

- [ ] Test a clean launch in airplane mode.
- [ ] Run the Map screen continuously for at least seven minutes.
- [ ] Repeat menu open/close at least 20 times.
- [ ] Switch tabs continuously for at least one minute.
- [ ] Background and foreground the app repeatedly.
- [ ] Lock and unlock the device while Map is active.
- [ ] Run once with Low Power Mode enabled.
- [ ] Verify there are no crashes.
- [ ] Verify there are no programming-error messages.
- [ ] Verify there are no missing-asset warnings.
- [ ] Verify there are no repeated SceneKit nodes.
- [ ] Verify no render loop remains active on blank tabs.
- [ ] Verify a release configuration build.

## Phase 2 Voice Verification

- [ ] `Hey GIA`, `GIA`, `G. I. A.`, and `gee eye ay` activate the assistant.
- [ ] `Georgia`, `giant`, `energy`, and ordinary conversation do not activate it.
- [ ] Manual activation enters the same transcription flow.
- [ ] Partial transcript text appears inside the active circle.
- [ ] Natural pauses shorter than 0.95 seconds do not end the request.
- [ ] Sustained silence completes a recognized request.
- [ ] Six seconds of initial silence produces a recoverable no-speech state.
- [ ] Capture stops at the maximum request duration.
- [ ] Returning stops transcription and resumes wake listening.
- [ ] Leaving Map stops microphone processing.
- [ ] Backgrounding and foregrounding do not duplicate audio taps.
- [ ] Permission denial leaves the manual interface available.
- [ ] Long transcripts remain legible with Dynamic Type.
- [ ] VoiceOver exposes the current phase and recognized transcript.
- [ ] No audio file is created or stored.

## Phase 2 Plan Handoff Verification

- [ ] Wake detection without a completed request does not change tabs.
- [ ] Request completion reaches validating before navigation.
- [ ] The compact indicator aligns with the contracted active circle.
- [ ] Plan is selected only once.
- [ ] No provider call begins during the handoff.
- [ ] Returning before completion cancels pending navigation.
- [ ] Backgrounding during handoff does not change tabs.
- [ ] Foregrounding an interrupted valid handoff safely resumes it.
- [ ] Reduce Motion uses a short crossfade without object movement.
- [ ] Plan status text accurately reflects every supported planning phase.

## Phase 2 Plan Shell Verification

- [ ] Header displays GIA, Plan identity, planning phase, and active status.
- [ ] The exact original request remains visible.
- [ ] Destination, dates, travelers, and budget show `Resolving` when absent.
- [ ] Resolved values do not truncate at standard Dynamic Type sizes.
- [ ] Flights, Stay, Experiences, Routes, and Weather appear exactly once.
- [ ] Module cards scroll horizontally without compressing their content.
- [ ] Validating modules remain queued.
- [ ] Ready modules require corresponding trip data.
- [ ] Request captured is the only initially complete timeline stage.
- [ ] Timeline content remains readable above persistent navigation.
- [ ] Increased Contrast strengthens surface boundaries.
- [ ] Reduce Transparency keeps all text readable.
- [ ] Reduce Motion stops indicator rotation.
- [ ] VoiceOver exposes request metrics, module statuses, and timeline statuses.
- [ ] No fake prices, result counts, itinerary items, or booking states appear.

## Phase 2 Request Interpretation Verification

- [ ] Destination is extracted from supported `to`, `visit`, and duration-in
  phrasing.
- [ ] Origin is extracted from explicit `from … to …` phrasing.
- [ ] Digit and common number-word traveler counts are recognized.
- [ ] Day, night, and week durations convert correctly.
- [ ] Numeric and spoken USD, EUR, and GBP budgets parse correctly.
- [ ] Interests, dietary needs, and accessibility needs remain distinct.
- [ ] Missing required fields move the session to clarification.
- [ ] Missing dates retain understood trip duration.
- [ ] Reversed and past date ranges are rejected.
- [ ] Invalid group sizes and budgets are rejected.
- [ ] Origin and destination cannot be identical.
- [ ] Selecting a request metric opens the matching editor.
- [ ] Save remains disabled for syntactically invalid values.
- [ ] Correcting one field preserves every other interpreted value.
- [ ] Remaining missing fields return the session to clarification.
- [ ] A complete correction returns the session to validation.
- [ ] Provider modules remain queued throughout clarification.

## Phase 2 Planning Progress Verification

- [ ] All nine workstreams begin queued.
- [ ] Validation activates only Request understanding.
- [ ] Clarification displays waiting-for-input state.
- [ ] No live provider status appears before search begins.
- [ ] Beginning search completes Request and Destination.
- [ ] Workstream updates are rejected from invalid planning phases.
- [ ] Result counts appear only after explicit provider completion.
- [ ] A zero-result provider response remains distinguishable from no response.
- [ ] Negative result counts are rejected.
- [ ] Provider attribution survives progress updates.
- [ ] Unavailable providers do not display complete state.
- [ ] Plan modules and process nodes use the same progress source.
- [ ] Cancel confirmation states that no booking occurred.
- [ ] Cancelling preserves completed work and cancels open work.
- [ ] Cancel returns to Map through the existing Earth animation.
- [ ] Returning clears the transient request and resumes wake listening.
- [ ] Date-only request values do not shift by one day across time zones.
- [ ] VoiceOver exposes each workstream name and status.

## Phase 2 Networking Foundation Verification

- [ ] Remote gateway URLs require HTTPS.
- [ ] Localhost HTTP remains available for development.
- [ ] No provider key exists in the iOS source or application bundle.
- [ ] Authorization is injected rather than hard-coded.
- [ ] Every request receives a unique request identifier.
- [ ] Typed JSON envelopes decode into domain contracts.
- [ ] Malformed responses produce decoding errors rather than crashes.
- [ ] Unauthorized and forbidden responses are not retried.
- [ ] HTTP 429, 502, 503, and 504 use bounded retries.
- [ ] `Retry-After` is honored without exceeding the maximum delay.
- [ ] Cancellation interrupts retry sleep.
- [ ] Internal transport errors map to safe client errors.
- [ ] Matching cached requests avoid duplicate transport calls.
- [ ] Cache filenames contain only SHA-256 material.
- [ ] Expired cache entries are rejected.
- [ ] Disk cache survives a cache-instance restart.
- [ ] iOS cache files receive data-protection attributes.
- [ ] Generated plans and speech are not cached by the response cache.
- [ ] Speech responses preserve audio content type.
- [ ] Provider-specific response headers are removed by the gateway.
- [ ] No live provider call or Plan progress mutation occurs in Card 9.

## Phase 2 Grounded GPT Planner Verification

- [ ] OpenAI is called only from the server gateway.
- [ ] Missing OpenAI configuration fails closed.
- [ ] The selected model is configured through `OPENAI_MODEL`.
- [ ] Responses requests set `store` to false.
- [ ] Output uses strict JSON schema through `text.format`.
- [ ] Raw spoken transcript is absent from model context.
- [ ] Checkout and booking URLs are absent from model context.
- [ ] Blueprint output contains no price, rating, availability, or booking field.
- [ ] Unknown flight and hotel selections are rejected.
- [ ] Unknown itinerary source identifiers are rejected.
- [ ] Free time cannot reference provider data.
- [ ] Sourced items cannot omit their source identifier.
- [ ] Reversed itinerary times are rejected.
- [ ] Items outside the trip dates are rejected.
- [ ] Overlapping itinerary items are rejected.
- [ ] Missing or additional schema properties are rejected.
- [ ] OpenAI authorization and response details are sanitized.
- [ ] The iOS client repeats critical grounding checks.
- [ ] Blueprint JSON survives Codable round trip.
- [ ] Mocked tests consume no OpenAI quota.

## Phase 2 SerpApi Flight Verification

- [ ] Invalid or identical IATA airports fail before network access.
- [ ] Missing endpoint time zones fail before network access.
- [ ] Reversed flight dates are rejected.
- [ ] Passenger and currency limits are validated.
- [ ] Travel class and stop preference map to documented parameters.
- [ ] One-way and round-trip request types map correctly.
- [ ] Best and other flight collections are both considered.
- [ ] Duplicate provider offers are removed.
- [ ] Offer and segment identifiers are deterministic.
- [ ] Segment local clock text is preserved.
- [ ] Origin and destination absolute times use resolved IANA zones.
- [ ] Connection airports without a zone remain explicitly unresolved.
- [ ] Price and currency decode into `Money`.
- [ ] Baggage descriptions remain source text.
- [ ] Price insights retain low/typical/high and typical range.
- [ ] Carbon estimates remain optional.
- [ ] Lowest, fastest, fewest-stop, and lower-emissions badges are deterministic.
- [ ] Provider mapping never assigns `giaRecommended`.
- [ ] Live provenance expires after three minutes.
- [ ] Booking URL remains an external continuation, not confirmation.
- [ ] Empty search results differ from malformed provider results.
- [ ] Provider errors and authorization details are sanitized.
- [ ] Flights progress uses the actual mapped result count.
- [ ] Mocked tests consume no SerpApi quota.

## Phase 2 SerpApi Hotel Verification

- [ ] Destination and destination time zone are required.
- [ ] Checkout must follow check-in.
- [ ] Adult and room limits are validated.
- [ ] Room count cannot exceed adult count.
- [ ] Currency, minimum class, and five-point guest rating are validated.
- [ ] Dates format in the destination time zone.
- [ ] Class, rating, free-cancellation, and maximum-price parameters map
  correctly.
- [ ] Provider filters are repeated after mapping.
- [ ] Property identifiers remain stable across retrievals.
- [ ] Lodging type maps without unsupported claims.
- [ ] Guest rating retains its explicit source scale.
- [ ] Nightly and total prices remain distinct.
- [ ] Missing total price derives from nightly price and calendar nights.
- [ ] Tax inclusion remains unknown unless source fields establish it.
- [ ] Unknown cancellation terms remain unknown.
- [ ] Typed amenities require matching source text.
- [ ] Image URLs are HTTPS, deduplicated, and bounded.
- [ ] Coordinates are range validated.
- [ ] Lowest-price and flexible badges are deterministic.
- [ ] Provider mapping never assigns `giaRecommended`.
- [ ] Empty results differ from malformed results.
- [ ] Constraint-filtered zero results remain valid.
- [ ] Hotel links remain external continuation, not confirmation.
- [ ] Stay progress uses the actual mapped result count.
- [ ] Provider failures are sanitized.
- [ ] Mocked tests consume no SerpApi quota.

## Phase 2 Restaurant and Activity Discovery Verification

- [ ] Destination, radius, limit, and categories are validated before requests.
- [ ] Food, museum, nature, shopping, nightlife, and sports interests expand
  categories correctly.
- [ ] Coordinate-based searches use Geoapify first.
- [ ] Geoapify requests use bounded circle filtering and proximity bias.
- [ ] Missing coordinates skip Geoapify and use SerpApi fallback.
- [ ] Geoapify failure uses SerpApi when configured.
- [ ] Geoapify zero results may use SerpApi fallback.
- [ ] Provider identifiers map to stable UUIDs.
- [ ] Coordinates are range validated.
- [ ] Typed categories reflect provider category evidence.
- [ ] Geoapify results do not fabricate ratings or reviews.
- [ ] Dietary options require provider category evidence.
- [ ] Wheelchair support requires explicit provider evidence.
- [ ] Unknown accessibility, reservation, indoor, cost, and duration remain nil.
- [ ] Opening-hour strings remain source text.
- [ ] Current open state appears only when explicitly supplied.
- [ ] SerpApi ratings, reviews, price level, hours, and images map correctly.
- [ ] Ordering links are not treated as booking links.
- [ ] HTTPS URLs are range checked and bounded.
- [ ] Place provenance identifies the actual contributing provider.
- [ ] Empty responses differ from malformed nonempty responses.
- [ ] Experiences progress uses the actual result count and providers.
- [ ] Mocked tests consume no Geoapify or SerpApi quota.

## Phase 2 Timed Event Verification

- [ ] Destination, IANA time zone, trip dates, query, and limit are validated.
- [ ] Event query contains destination and requested date range.
- [ ] Interests select an appropriate event topic.
- [ ] Exact source date text is preserved.
- [ ] ISO dates parse directly.
- [ ] Month/day dates infer a year only from the trip range.
- [ ] 12-hour and 24-hour clock ranges parse correctly.
- [ ] Local event times convert through the destination time zone.
- [ ] Overnight end times remain chronological.
- [ ] Missing clock ranges leave start/end unresolved.
- [ ] Unresolved events do not receive fixed-time status.
- [ ] Postponed events lose fixed schedule placement.
- [ ] Cancelled events are excluded.
- [ ] Expired resolved events are excluded.
- [ ] Recognizable out-of-range events are excluded.
- [ ] Duplicate provider events are removed.
- [ ] Ticket links require explicit ticket link type.
- [ ] Venue rating retains its five-point scale.
- [ ] Outdoor/weather-dependent traits require text evidence.
- [ ] Event result identity remains deterministic.
- [ ] Empty results differ from malformed provider results.
- [ ] Experiences progress uses the actual event count.
- [ ] GPT blueprint validation rejects unknown event IDs.
- [ ] Mocked tests consume no SerpApi quota.

## Phase 2 Transportation Routing Verification

- [ ] Origin and destination require identifiers, names, and valid coordinates.
- [ ] Identical coordinates are rejected.
- [ ] One to four unique route modes are accepted.
- [ ] Unsupported carrier-specific modes fail before provider access.
- [ ] Walking maps to Geoapify walk mode.
- [ ] Bicycle maps to bicycle mode.
- [ ] Car and rideshare estimates map to drive mode.
- [ ] Driving requests use approximated traffic rather than claiming live traffic.
- [ ] Transit attempts scheduled routing first.
- [ ] Empty scheduled transit falls back to approximated transit.
- [ ] Approximated transit retains explicit approximated confidence.
- [ ] Duration and distance must be positive.
- [ ] Planned arrival derives only from provider duration.
- [ ] Planning buffers remain separate from provider duration.
- [ ] Nested GeoJSON route geometry flattens correctly.
- [ ] Invalid coordinates inside route geometry are discarded.
- [ ] Geometry is bounded and preserves the final destination point.
- [ ] Instructions are extracted, deduplicated, and bounded.
- [ ] Estimated cost and booking URL remain nil without source evidence.
- [ ] Route provenance expires after 15 minutes.
- [ ] Empty routes differ from malformed nonempty routes.
- [ ] Partial multi-mode success remains available.
- [ ] Routes progress uses the actual result count.
- [ ] Mocked tests consume no Geoapify quota.

## Phase 2 Weather Intelligence Verification

- [ ] Location identifier, name, coordinate, and IANA time zone are required.
- [ ] Reversed and completed trip dates fail before provider access.
- [ ] Forecast horizon is calculated in the destination time zone.
- [ ] Distant trips return no snapshots without consuming provider quota.
- [ ] Request day count is bounded by configured provider capability.
- [ ] Alerts are requested only when enabled.
- [ ] Only hours intersecting trip dates are retained.
- [ ] Condition text and code remain provider evidence.
- [ ] Clear, cloudy, fog, rain, snow, storm, and wind map deterministically.
- [ ] Rain/snow probability is normalized from 0–100 to 0–1.
- [ ] Missing probability remains nil rather than zero.
- [ ] Missing temperature, feels-like, and wind remain nil.
- [ ] Alert headline, agency, severity, timing, instructions, and URL map safely.
- [ ] Duplicate and expired alerts are removed.
- [ ] Weather provenance expires after 15 minutes.
- [ ] Provider URLs containing API keys never reach the app.
- [ ] Missing forecast structure differs from an out-of-range empty result.
- [ ] Weather progress uses actual snapshot count.
- [ ] Distant zero results display forecast-not-yet-available context.
- [ ] Severe alerts create critical avoid-outdoor advisories.
- [ ] Likely rain creates prefer-indoor advisories.
- [ ] Snow, wind, and extreme temperature rules remain deterministic.
- [ ] Advisories do not automatically modify itinerary items.
- [ ] Mocked tests consume no WeatherAPI quota.

## Phase 2 Translation Verification

- [ ] Text length, language codes, content kind, and protected-term count are
  validated.
- [ ] Provider must be explicitly selected.
- [ ] Remote provider endpoint requires HTTPS.
- [ ] Google and DeepL endpoints remain host allowlisted.
- [ ] URLs, emails, identifiers, ISO dates, currency amounts, and GIA are
  protected automatically.
- [ ] Caller-supplied names remain byte-for-byte unchanged.
- [ ] Leading and trailing segment whitespace survives translation.
- [ ] Addresses and identifiers bypass provider access.
- [ ] Same-language requests bypass provider access.
- [ ] No-translatable-text requests bypass provider access.
- [ ] Google request and detected-language response map correctly.
- [ ] Google HTML entities decode safely.
- [ ] DeepL uses server-side authorization header.
- [ ] LibreTranslate requires explicit configured endpoint.
- [ ] Segment-count mismatch and empty segments are rejected.
- [ ] Original and translated text remain available together.
- [ ] Machine translation is explicitly labeled.
- [ ] Provider provenance and 24-hour expiration are retained.
- [ ] Matching requests use memory cache.
- [ ] Translation responses are not written to disk cache.
- [ ] Provider credentials and errors remain server-side.
- [ ] Mocked tests consume no translation quota.

## Phase 2 Flight Comparison Verification

- [ ] Flight comparison appears only when sourced offers exist.
- [ ] Selected or grounded-recommended offer receives initial focus.
- [ ] Focusing an alternative does not change trip selection.
- [ ] Selecting an offer validates its UUID against the trip catalog.
- [ ] Unknown offer selection is rejected.
- [ ] Shared-trip selection updates exactly once.
- [ ] Up to three offers can enter temporary comparison.
- [ ] Comparison state does not persist as a trip selection.
- [ ] Airline, route, date, local clocks, duration, stops, and total price render.
- [ ] Baggage zero counts are omitted.
- [ ] Emissions remain unavailable when the provider omitted them.
- [ ] Price-insight icon matches low, typical, and high state.
- [ ] Unresolved connection time zones display a warning.
- [ ] Missing return segments display return-selection-pending.
- [ ] Data origin displays Live, Cached, Demo, or User.
- [ ] Debug fixtures never display Live.
- [ ] Provider action says View with Provider.
- [ ] Provider action states that no booking has been made.
- [ ] Provider action does not mutate booking status.
- [ ] Expanded segment details remain readable with Dynamic Type.
- [ ] Comparison cards expand vertically rather than clipping text.
- [ ] VoiceOver summarizes each focused flight and comparison metric.

## Phase 2 Hotel Comparison Verification

- [ ] Hotel comparison appears only when sourced offers exist.
- [ ] Selected or grounded-recommended property receives initial focus.
- [ ] Focusing an alternative does not change trip selection.
- [ ] Selecting a property validates its UUID against the trip catalog.
- [ ] Unknown hotel selection is rejected.
- [ ] Shared-trip hotel selection updates exactly once.
- [ ] Up to three hotels can enter temporary comparison.
- [ ] Temporary comparison does not mutate the selected hotel.
- [ ] Hotel name, location, type, class, rating, and reviews render.
- [ ] Guest rating always displays its source scale.
- [ ] Star class remains separate from guest rating.
- [ ] Nightly and total prices remain visibly distinct.
- [ ] Missing nightly price remains unavailable.
- [ ] Unknown taxes and cancellation remain unconfirmed.
- [ ] Typed amenities remain source-backed.
- [ ] Provider images load only from supplied HTTPS URLs.
- [ ] Missing/failed images use the original spatial placeholder.
- [ ] Debug fixtures never display Live.
- [ ] Provider action says View with Provider.
- [ ] Provider action states that no reservation has been made.
- [ ] Provider action does not mutate booking status.
- [ ] Comparison cards expand rather than clipping names or cancellation text.
- [ ] VoiceOver summarizes each property and comparison metric.

## Phase 2 Spatial Timeline Verification

- [ ] Itinerary days and items appear chronologically.
- [ ] Day selector uses destination-local calendar dates.
- [ ] Weather summary requires a matching sourced snapshot.
- [ ] Item time range uses the item's IANA time zone.
- [ ] Selected status does not imply booking.
- [ ] Fixed, flexible, and user-locked states remain distinct.
- [ ] Drag handles appear only for flexible items.
- [ ] Dragging snaps to 15-minute increments.
- [ ] Drag interaction does not block vertical timeline scrolling.
- [ ] Valid moves preserve duration and chronological order.
- [ ] Overlapping moves are rejected without changing the trip.
- [ ] Fixed and locked items cannot move.
- [ ] Flexible items can be locked.
- [ ] User-locked items can be unlocked.
- [ ] Items cannot move outside trip dates.
- [ ] Items cannot move to a nonexistent itinerary day.
- [ ] Adjacent locations use a matching sourced transportation leg.
- [ ] Missing transportation displays Route not connected.
- [ ] Route mode, duration, and confidence remain sourced.
- [ ] Costs remain estimated unless booking state proves otherwise.
- [ ] Expanded notes remain readable at accessibility text sizes.
- [ ] Movable items expose VoiceOver earlier/later actions.
- [ ] Fixed/locked items do not expose ineffective move actions.
- [ ] Reduce Motion resets drag position without animated travel.

## Phase 2 ElevenLabs Response Verification

- [ ] The iOS application contains no ElevenLabs API key.
- [ ] The gateway rejects empty, oversized, wrong-voice, and unsupported-format
  requests.
- [ ] Provider authorization and quota details never reach the client.
- [ ] Speech responses are `audio/mpeg` and `Cache-Control: no-store`.
- [ ] The microphone audio session stops before speech generation begins.
- [ ] “Okay, I've got it” continues across the Map-to-Plan transition.
- [ ] Clarification uses “I need one more detail.”
- [ ] Real playback levels drive the assistant ripple.
- [ ] Repeated common phrases use the in-memory audio cache.
- [ ] Generated audio is never written to the gateway response cache.
- [ ] Missing gateway configuration preserves visible response text.
- [ ] Failed playback shows a dismissible Voice unavailable banner.
- [ ] A failed voice response never blocks Plan navigation.
- [ ] VoiceOver does not duplicate generated G.I.A. audio.
- [ ] Returning to Map resumes wake listening after playback is stopped.
- [ ] Backgrounding or starting another response cancels stale playback.

## Phase 2 Selection and Demo Confirmation Verification

- [ ] Selecting a flight or hotel opens the review sheet.
- [ ] Review displays sourced total, provider, origin, retrieval time, and
  cancellation/change terms.
- [ ] FBLA mode is labeled “FBLA Demonstration.”
- [ ] Demo Continue collects no payment information.
- [ ] Demo Continue displays “Demo booking confirmed.”
- [ ] Demo record uses `.demo` and `.demoConfirmed`.
- [ ] Demo record contains no provider confirmation code.
- [ ] External mode is labeled “External Provider Checkout.”
- [ ] External Continue opens only the supplied provider URL.
- [ ] External record remains `.externalCheckoutRequired`.
- [ ] Missing checkout URL produces an error without a booking record.
- [ ] Flight confirmation adds outbound/return fixed itinerary nodes.
- [ ] Hotel confirmation adds fixed check-in/check-out nodes.
- [ ] Demo itinerary notes state that no real ticket or room exists.
- [ ] Repeating confirmation does not duplicate the active record.
- [ ] Superseded unfinished records become cancelled but remain in history.
- [ ] Provider-confirmed records cannot be replaced or downgraded.
- [ ] Flight/hotel section headers distinguish Demo, Checkout required, and
  Provider confirmed states.
- [ ] VoiceOver reads the truth disclosure and confirmation state.

## Phase 2 Group Workspace Verification

- [ ] Group tab shows an empty state when no trip exists.
- [ ] Only accepted `Trip.travelers` can access a trip workspace.
- [ ] A pending invitation does not grant access.
- [ ] Organizer and Member roles are visibly distinct.
- [ ] Only the organizer can invite, revoke, or remove.
- [ ] Invitation name and email validation reject malformed input.
- [ ] Duplicate pending invitations are rejected.
- [ ] Invitation acceptance requires the invited email identity.
- [ ] Accepted invitees join with Member role.
- [ ] Availability and tentative states remain distinct.
- [ ] Personal budget is hidden when preference visibility denies access.
- [ ] Private-to-traveler preferences are visible only to their owner.
- [ ] Organizer-only preferences are visible to the owner and organizer.
- [ ] Trip-member preferences are visible to all accepted members.
- [ ] Travelers can change only their own visibility setting.
- [ ] Removing the organizer is rejected.
- [ ] Removing a member immediately removes access.
- [ ] Removing a member preserves prior votes and decisions.
- [ ] Removal appends a permanent audit record with former name and role.
- [ ] Pending invitations can be revoked without deleting audit history.
- [ ] Legacy trips without collaboration data still decode.
- [ ] Dynamic Type does not clip member names, constraints, or privacy labels.
- [ ] VoiceOver identifies roles, availability, budgets, and privacy state.

## Phase 2 Voting and Approvals Verification

- [ ] Only the organizer can open a proposal or choose its approval rule.
- [ ] Destination, dates, flights, hotels, places, itinerary, and budget
  subjects resolve only from current trip data.
- [ ] Invalid or removed subjects are rejected.
- [ ] Eligible traveler IDs are snapshotted when voting opens.
- [ ] Uninvited travelers cannot vote.
- [ ] A traveler cannot submit a second ballot.
- [ ] Majority requires more than half of eligible travelers.
- [ ] Unanimous requires Yes from every eligible traveler.
- [ ] Any No ballot rejects a unanimous decision.
- [ ] Organizer rule accepts only the organizer's ballot.
- [ ] Yes, No, Pass, pending, and required totals are exact.
- [ ] Voting closes immediately when a threshold resolves the outcome.
- [ ] Closed decisions reject later ballots.
- [ ] A complete vote without a threshold becomes visibly Tied.
- [ ] Tie state is not displayed as approval.
- [ ] Organizer can create a revision from Tie, Rejected, or Needs Revision.
- [ ] Revision has a new ID and an empty ballot.
- [ ] Revision references the superseded decision.
- [ ] Original votes, result, and timestamp remain unchanged.
- [ ] No fake percentages are displayed.
- [ ] VoiceOver reads decision subject, rule, state, tally, and vote actions.

## Phase 2 Group Communication Verification

- [ ] Only accepted trip members can send, mention, react, or mark read.
- [ ] Empty and over-2,000-character messages are rejected.
- [ ] Whole-trip messages retain Whole trip context.
- [ ] Item discussion stores and displays the itinerary item identifier.
- [ ] Decision discussion stores and displays the decision identifier.
- [ ] Invalid or removed contexts cannot receive new messages.
- [ ] Mention menu includes only current accepted members.
- [ ] Unknown mentions are rejected.
- [ ] Self-mentions are removed.
- [ ] G.I.A. messages display `GIA · ASSISTANT`.
- [ ] System messages display `TRIP UPDATE`.
- [ ] Member messages never render as G.I.A. or System.
- [ ] Booking, decision, itinerary, invite, join, and removal changes create
  typed system messages.
- [ ] Approve, Heart, Celebrate, and Question reactions toggle idempotently.
- [ ] Duplicate traveler/reaction pairs are rejected structurally.
- [ ] Opening chat creates at most one read receipt per traveler/message.
- [ ] Unread and read counts match stored receipts.
- [ ] Removed-member messages remain visible as Former member.
- [ ] Share control opens the native iOS share sheet.
- [ ] At least one installed social or messaging app is reachable from share.
- [ ] Shared text omits emails, chat content, private notes, dietary needs,
  accessibility needs, budgets, and booking identifiers.
- [ ] VoiceOver reads author, context, body, reactions, and send controls.

## Phase 2 SwiftData Offline Storage Verification

- [ ] Ready and partially available trips autosave after mutations.
- [ ] Backgrounding flushes pending trip state immediately.
- [ ] Saving the same Trip UUID updates one record.
- [ ] Travelers, selections, catalog, itinerary, budget, bookings, decisions,
  votes, collaboration, messages, reactions, receipts, weather, and provenance
  survive relaunch.
- [ ] Raw voice transcript is absent from the persisted payload.
- [ ] Provider keys, gateway credentials, and generated speech are not stored.
- [ ] Most recently saved valid trip restores without network.
- [ ] Restored session rebuilds progress and budget/conflict analysis.
- [ ] Restored active identity is an accepted trip member.
- [ ] Invalid payloads do not enter `TripPlanningSession`.
- [ ] Newer unsupported Trip schemas remain stored and are not deleted.
- [ ] SwiftData uses the declared versioned schema and migration plan.
- [ ] Persistent-container failure uses a visible in-memory fallback.
- [ ] Group storage surface displays saved age and oldest source age.
- [ ] Demo trips remain visibly labeled.
- [ ] Offline library lists multiple saved trips newest first.
- [ ] Open action restores the selected local trip.
- [ ] Delete requires explicit confirmation.
- [ ] Delete warning says provider reservations are not cancelled.
- [ ] Deleting one trip does not delete other or unsupported records.
- [ ] Gateway response-cache expiration remains separate from durable trips.
- [ ] VoiceOver reads storage status, age, open, and delete actions.

## Phase 2 Judge-Safe Offline Demo Verification

- [ ] Airplane mode does not prevent manual Offline Demo launch.
- [ ] Hamburger menu exposes Start, Restart, and Reset controls.
- [ ] Manual start preserves the assistant-to-Plan transition.
- [ ] Unresolved normal planning preserves its requested destination.
- [ ] No timeout, offline, or provider failure can load the demo fixture.
- [ ] Manual banner says Judge demo started manually.
- [ ] Plan banner says no live booking or provider availability is claimed.
- [ ] Flight and hotel modules contain at least two options each.
- [ ] Restaurants, activities, fixed event, weather, and routes are present.
- [ ] Timeline contains at least two days with transportation connectors.
- [ ] Budget includes every category and emergency reserve.
- [ ] Every provider-backed fixture object has Demo origin.
- [ ] No Demo result displays Live or Cached.
- [ ] App relaunch starts on clean Map without restoring the demo.
- [ ] Reset clears the in-memory demo and returns to idle Map.
- [ ] Restart produces the same deterministic Trip UUID.
- [ ] Reduced Motion uses the existing crossfade/handoff behavior.
- [ ] Full judge journey can be demonstrated in under seven minutes.

## Phase 2 Notifications and Calendar Verification

- [ ] No notification or calendar permission appears at app launch.
- [ ] Enable Alerts requests notification permission contextually.
- [ ] Export Plan requests calendar permission contextually.
- [ ] Permission denial leaves Map, Plan, and Group usable.
- [ ] Countdown schedules seven days before at 9:00 destination time.
- [ ] Open/tied decisions receive one stable voting reminder.
- [ ] Itinerary changes receive one generic schedule-change alert.
- [ ] Flight check-in reminder occurs 24 hours before departure.
- [ ] Departure reminder occurs three hours before departure.
- [ ] Hotel check-in reminder occurs two hours before check-in.
- [ ] Moderate/severe/extreme weather alerts schedule; expired alerts do not.
- [ ] Pending reminders use stable trip/source identifiers.
- [ ] Refresh replaces pending reminders without duplicates.
- [ ] Delivered schedule-change reminders are not re-added.
- [ ] Reminder copy excludes names, emails, preferences, budgets, chat, and
  booking identifiers.
- [ ] Flight reminders use departure airport time zone.
- [ ] Countdown/voting use destination time zone.
- [ ] Hotel/calendar items use itinerary time zone.
- [ ] Weather warnings use weather snapshot time zone.
- [ ] App activation and system time-zone changes refresh enabled reminders.
- [ ] EventKit export includes every non-cancelled chronological item.
- [ ] Repeated export updates marker-matched events instead of duplicating.
- [ ] Calendar export records persist EventKit identifiers and time zones.
- [ ] Calendar notes say provider booking details still require verification.
- [ ] Deleting local trip data does not claim to delete calendar events.
- [ ] VoiceOver reads countdown, status, permission, and export actions.

## Phase 2 Accessibility and Performance Verification

- [ ] VoiceOver traverses Map, Plan, and Group in logical order.
- [ ] Every interactive image has a meaningful label.
- [ ] No essential action is drag-only, color-only, or animation-only.
- [ ] All custom controls provide at least a 44-point target.
- [ ] Accessibility text sizes switch request metrics to one column.
- [ ] Accessibility text sizes stack Trip Alert and Calendar cards.
- [ ] Persistent navigation remains bounded at the largest text size.
- [ ] Essential content scrolls instead of clipping.
- [ ] Increased Contrast strengthens borders and unselected navigation.
- [ ] Reduce Transparency removes translucent surface highlights.
- [ ] Reduce Motion stops continuous Earth and voice-ripple animation.
- [ ] Reduce Motion makes timeline, comparison, chat, and reset changes
  immediate.
- [ ] Hidden Map does not run the 60 FPS active-voice TimelineView.
- [ ] Plan/Group selection pauses SceneKit continuous rendering.
- [ ] Returning to Map resumes Earth rendering only when allowed.
- [ ] Memory warning purges speech cache and hidden SceneKit actions.
- [ ] Microphone denial does not trigger an unnecessary speech prompt.
- [ ] Manual and judge-safe flows work with microphone unavailable.
- [ ] Slow/offline provider paths remain cancellable and use visible fallback.
- [ ] iPhone SE layout keeps navigation and core Plan information usable.
- [ ] iPhone 17 Pro Max at AX5/Increase Contrast remains scrollable.
- [ ] Time Profiler reports no 250ms+ potential hangs while idle on Plan.
- [ ] Physical device sustains smooth core animation without thermal warning.

## Phase 7 Failure and End-to-End QA

- [x] Known offline state preserves the requested destination in memory.
- [x] Offline state shows Retry and New Request without inserting demo data.
- [x] Unreachable gateway shows queued work without fabricated counts.
- [x] Provider-unavailable state shows no empty itinerary shells.
- [x] Disabled speech preserves visible response text and opens Plan.
- [x] Denied microphone access leaves Settings and Type available.
- [x] Chicago, Tokyo, Lisbon, Vancouver, and Reykjavík use one request path.
- [x] Repeated requests replace prior in-memory state.
- [x] Judge demo activation is manual-only.
- [x] Demo reset returns the session to idle.
- [x] iPhone SE accessibility-size-5 layout remains scrollable.
- [x] iPhone 17 Pro Max accessibility-size-5 layout remains scrollable.
- [x] Reduce Motion stops visible Earth rotation across timed captures.
- [x] Seven-minute active-Map simulator soak finishes without app error logs.
- [ ] Ten acoustic wake tests pass on a physical iPhone.
- [ ] Five microphone requests pass on a physical iPhone.
- [ ] VoiceOver swipe order is verified with spoken output.
- [ ] Real audio interruptions stop and recover cleanly.
- [ ] Seven-minute physical-device thermal run completes without warning.
- [ ] Deployed gateway and live provider credentials pass end to end.

## Conversational Plan Edit Verification

- [x] The Voice Ready visual badge is absent.
- [x] Request capture completes after 0.95 seconds of transcript silence.
- [x] Ambient microphone energy cannot extend transcript completion.
- [x] Listening waveform requires recently recognized transcript speech.
- [x] Stale transcript plus background noise fades the waveform to zero.
- [x] Six seconds without speech creates a recoverable failure.
- [x] Twenty seconds completes a request with available transcript text.
- [x] Wake aliases work while a ready Plan is visible.
- [x] Initial activation speaks a short rotating human greeting.
- [x] Request transcription begins only after the greeting completes.
- [x] A stalled greeting cannot block listening longer than six seconds.
- [x] Wake recognition remains armed across Map, Plan, and Group.
- [x] Active provider planning can be interrupted and restarted safely.
- [x] G.I.A. playback pauses microphone recognition.
- [x] Backgrounding stops recognition and foregrounding rearms it.
- [x] Follow-up invocation returns from Plan to Map.
- [x] Follow-up prompt precedes microphone transcription.
- [x] Destination and budget updates rebuild a clean progressive Plan.
- [x] Interests, dietary needs, accessibility needs, flight preferences, and
  stay preferences support deterministic add/remove operations.
- [x] Cancel and Return preserve the existing Plan.
- [x] Unsupported changes preserve the existing Plan.
- [x] Typed follow-up commands use the same mutation path.
- [x] Continued clauses such as “Italy and make sure…” preserve Italy.
- [x] Missing details are asked one at a time on Map.
- [x] Missing budget is accepted and displayed as No limit set.
- [x] “That's it,” “done,” and “use that” finish optional preferences.
- [x] Plan clarification uses a conversation link instead of a field form.
- [x] On-device speech replaces Voice unavailable when ElevenLabs is absent.
- [x] ElevenLabs voice ID is fixed server-side to
  `3Drdg7QWqr45nZmYpXRP`.
- [x] Stop and goodbye commands respond with “See you later.”
- [x] Stop preserves a completed Plan and closes an incomplete conversation.
- [x] “Bus stop” and “stop at a museum” do not trigger conversation shutdown.
- [ ] Physical-device wake and follow-up timing pass in realistic room noise.
- [ ] Repeated Map/Plan/Group switching shows no leaks or unbounded growth.

## Performance Evidence

Record the following after implementation:

- Device and iOS version:
- Build configuration:
- Earth texture dimensions and file size:
- Map frame-rate observation:
- Memory after launch:
- Memory after repeated tab switching:
- Device thermal observation after seven minutes:
- Rendering state while Plan is selected:
- Rendering state while Group is selected:
- Instruments session date:
- Defects discovered:
- Corrective actions:

## Test Result Sign-Off

- Tester:
- Date:
- App version:
- Build number:
- Commit:
- Result:
- Remaining issues:
