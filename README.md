# Wanderlust
Imagine traveling with your omnicient friend who happens to be a local wherever you go.

## LLM setup

The existing bundled `oa.enc` credential is installed into the device Keychain on
first launch and reused by the OpenAI Responses API client. The two system prompts,
response schemas, and selected model live in
`Wanderlust/Screens/Output/TripPlanningService.swift`. The OpenAI Responses API
adapter lives in `Packages/Networking/Sources/Networking/LLM`.

This client-direct setup is convenient for development, but a key shipped inside a
mobile app can be extracted. Move the LLM call behind a server endpoint before a
public production release that needs meaningful key protection or per-user limits.
