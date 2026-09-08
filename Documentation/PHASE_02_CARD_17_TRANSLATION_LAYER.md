# Phase 2 — Card 17: Source-Preserving Translation

## Status

Source complete. Phase 8 selected Google Cloud Translation and connected
on-demand Plan descriptions. Live verification remains blocked because the
current translation credential is not a valid Google API key.

## Objective

Translate travel descriptions and messages while preserving original text,
proper names, addresses, URLs, dates, amounts, and booking identifiers.

## Domain contract

`TranslatedText` stores:

- Original text
- Translated text
- Requested source language
- Detected source language
- Target language
- Content kind
- Protected terms
- Machine-translated status
- Provider provenance

The original is never discarded.

## Content kinds

- Plain text
- Place description
- Address
- Travel message
- Identifier

Addresses and identifiers bypass machine translation entirely. They remain
exact and are marked `isMachineTranslated = false`.

## Supported server providers

The gateway adapter supports:

- Google Cloud Translation Basic
- DeepL Free or Pro
- A trusted HTTPS LibreTranslate deployment

Configuration:

```text
TRANSLATION_PROVIDER=google | deepl | libretranslate
TRANSLATION_API_KEY=...
TRANSLATION_BASE_URL=...
```

Google and DeepL use allowlisted official hosts. LibreTranslate requires an
explicit HTTPS base URL.

The apparent current key cannot safely identify its provider. No provider is
selected automatically from credential text.

## Protected-term strategy

G.I.A. does not ask a translation model to preserve placeholders. Instead, it:

1. Finds protected ranges.
2. Splits the input into protected and translatable segments.
3. Removes leading/trailing whitespace from provider segments.
4. Translates only textual cores.
5. Restores whitespace.
6. Recombines protected values exactly.

Automatically protected:

- HTTPS/HTTP URLs
- Email addresses
- Uppercase alphanumeric identifiers of six or more characters
- ISO dates
- Currency amounts
- GIA/G.I.A.

Caller-supplied terms protect:

- Place names
- Hotel names
- Restaurant names
- Traveler names
- Provider confirmation identifiers
- Other context-specific terms

## Input validation

- Text length: 1–5,000 characters
- BCP-47-like source and target language codes
- Maximum 50 protected terms
- Maximum protected-term length of 200
- Supported content kind
- HTTPS provider endpoint

Same-language requests bypass provider access.
Inputs containing no translatable text also bypass provider access.

## Provider mapping

Google:

- JSON `q` segments
- Optional source language
- Target language
- Plain-text format
- API key added server-side
- HTML entities decoded after translation

DeepL:

- JSON text segments
- Optional source language
- Target language
- `DeepL-Auth-Key` server header
- Free or Pro official endpoint

LibreTranslate:

- JSON text segments
- Automatic source detection when omitted
- Target language
- API key in server request body
- Explicit HTTPS deployment endpoint

## Caching and privacy

Translation responses use a 24-hour memory-only cache.

They are not written to the gateway disk cache because a translation may
contain traveler messages, dietary needs, accessibility information, or other
sensitive text. Cache filenames remain SHA-256 request hashes.

## Failure behavior

Safe errors cover:

- Missing provider selection
- Missing credential
- Missing LibreTranslate endpoint
- Insecure or unapproved endpoint
- Invalid text/language/content kind
- Too many protected terms
- Timeout
- Transport failure
- Rate limit
- Authorization failure
- Provider failure
- Invalid JSON
- Unsupported provider response
- Segment-count mismatch
- Empty translated segment

Upstream response bodies and credentials never reach the iOS app.

## Verification

Gateway tests cover:

- Language, size, and content-kind validation
- Automatic URL, email, identifier, date, currency, and GIA protection
- Caller-supplied proper-name protection
- Exact recombination
- Whitespace preservation
- Google request and response mapping
- DeepL header and payload mapping
- Same-language bypass
- Address and identifier bypass
- Segment-count rejection
- Sanitized authorization failure
- Provider and endpoint fail-closed behavior

Swift verification confirms:

- Exact `TranslatedText` decoding
- Original and translated text coexist
- Protected names and dates remain exact
- Provider provenance
- Machine-translation label
- Matching requests use memory cache
- Translation does not create disk cache files
- Successful iOS build

No test consumes translation quota.

## FBLA evidence

This card supports:

- International usability
- Secure credential handling
- Data integrity
- Privacy-conscious caching
- Professional source preservation
- Explainable machine-translation labeling
- Provider-independent architecture
