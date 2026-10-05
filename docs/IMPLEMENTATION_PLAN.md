# SnapChef Flutter MVP Implementation Plan

SnapChef is a Flutter mobile app that turns photographed or manually entered ingredients into ranked recipe recommendations. This plan turns the functional requirements into buildable increments with explicit checkpoints for a student-team MVP.

## MVP success condition

A user can register, set meal/cuisine/allergen preferences, capture or enter ingredients, correct the detected list, receive ranked recipes, open recipe details, and create either a private or community recipe.

## Proposed technical direction

- Flutter and Dart, organized by feature.
- Firebase Authentication, Cloud Firestore, Cloud Storage, and server-side functions as the proposed backend default.
- A replaceable image-analysis service called through the backend; provider secrets must never be shipped in the Flutter client.
- One consistent state-management approach; Riverpod is the proposed default.
- Unit tests for validation and ranking, widget tests for important forms and states, and integration tests for the primary user journey.
- Protected `main`, short-lived feature branches, pull-request review, formatting, static analysis, and automated tests.

These are proposed defaults and should be confirmed during Phase 0.

## Team ownership

Owners lead design and integration for their stream. Every major pull request needs a reviewer from another stream.

| Workstream | Lead | Responsibilities |
| --- | --- | --- |
| Accounts and preferences | Hetal Halani | Registration, login, sessions, account deletion, meal types, cuisines, allergens |
| Ingredient capture and recommendations | Joël Moyal | Camera/gallery, permissions, recognition integration, ingredient correction, matching and ranking |
| Recipe authoring and community | Newton Tran | Recipe CRUD, private recipes, publishing, community feed, filters, ownership rules |
| Shared engineering quality | Entire team | Data model, UI conventions, review, tests, demos, documentation |

## Delivery phases and checkpoints

### Phase 0: Product and architecture alignment

**Target: 2–3 working days**

- [ ] Confirm the MVP boundary and deferred features.
- [ ] Confirm Android, iOS, or both as demo platforms.
- [ ] Choose the backend and ingredient-recognition provider.
- [ ] Define account-deletion and recipe-visibility behavior.
- [ ] Finalize meal type, cuisine, allergen, and measurement-unit lists.
- [ ] Sketch core screens and navigation.
- [ ] Define the data model and repository interfaces.
- [ ] Create the Flutter project setup, environments, linting, branch rules, and CI.

**Checkpoint 0 — Foundation approved:** The team can explain the complete user journey; ownership and visibility rules are resolved; the app builds on every target platform; and a pull request runs formatting, analysis, and tests.

### Phase 1: App shell, authentication, and preferences

**Target: Week 1**

- [ ] Build navigation, theme, loading states, error presentation, and reusable form controls.
- [ ] Implement registration with first name, last name, email, and password.
- [ ] Implement login, persistent sessions, logout, invalid credentials, and duplicate-email handling.
- [ ] Implement meal type, cuisine, and allergen selection and editing.
- [ ] Persist preferences per user.
- [ ] Add confirmed account deletion using the agreed data policy.
- [ ] Add validation and widget tests.

**Checkpoint 1 — Persistent personalized account:** A user can register, restart without losing the session, update preferences, log out, log back in, and request deletion. Invalid input is actionable and another user cannot access the account data.

### Phase 2: Recipe domain and seed catalog

**Target: Week 2**

- [ ] Implement user, preference, recipe, ingredient, and visibility models.
- [ ] Define canonical ingredient-name normalization.
- [ ] Add a seed catalog covering multiple meals, cuisines, and allergens.
- [ ] Implement recipe detail with quantities, units, numbered steps, and allergen information.
- [ ] Keep UI code behind repository interfaces.
- [ ] Test serialization, validation, normalization, and allergen matching.

**Checkpoint 2 — Trusted recipe data:** Seed recipes load and open without missing required data; invalid recipes are rejected; normalization and allergen test cases pass.

### Phase 3: Ingredient capture and correction

**Target: Week 3**

- [ ] Add camera capture and photo-library selection.
- [ ] Request permissions only when needed.
- [ ] Explain denied permissions and offer manual entry.
- [ ] Submit images through a protected backend integration.
- [ ] Show analyzing, success, empty-result, failure, and retry states.
- [ ] Combine duplicate detections.
- [ ] Let users add, remove, and rename ingredients before confirmation.
- [ ] Test permissions, offline behavior, timeouts, empty detection, and retry.

**Checkpoint 3 — Reliable ingredient input:** On a physical device, camera, gallery, and manual entry work; results are editable; duplicates combine; recognition failure never blocks manual entry; and a confirmed list reaches recommendations.

### Phase 4: Recommendation engine

**Target: Week 4**

- [ ] Exclude recipes conflicting with selected allergens and preferences.
- [ ] Require at least one matched confirmed ingredient.
- [ ] Calculate matched and missing ingredient counts.
- [ ] Sort by fewest missing ingredients, then most matched ingredients.
- [ ] Show title, photo when available, meal type, cuisine, and match counts.
- [ ] Label recipe-detail ingredients as available or missing.
- [ ] Refresh after ingredient or preference changes.
- [ ] Provide actions for no-match states.
- [ ] Unit-test filtering, ranking, ties, normalization, and empty inputs.

**Checkpoint 4 — End-to-end core value:** A photo or manual list produces deterministic recommendations that obey preferences and allergens; ordering and detail labels are correct; changing inputs refreshes results.

### Phase 5: Personal recipes and publishing

**Target: Week 5**

- [ ] Build recipe creation with required title, meal type, cuisine, allergens/None, ingredients with quantity and unit, and preparation steps.
- [ ] Support optional recipe photos.
- [ ] Validate every required field inline.
- [ ] Support private and published visibility plus My Recipes.
- [ ] Allow authors to edit or delete their own recipes with confirmation.
- [ ] Enforce ownership and visibility in backend rules, not only in the UI.
- [ ] Include eligible published user recipes in recommendations.
- [ ] Test authorization, validation, upload, edit, delete, and visibility.

**Checkpoint 5 — Safe recipe ownership:** Private and public recipes appear in the correct lists; authors can edit/delete only their own recipes; published user recipes can be recommended; unauthorized writes are rejected by backend rules.

### Phase 6: Community experience

**Target: Week 6**

- [ ] Show published recipes newest first.
- [ ] Display title, author first name, meal type, cuisine, and optional photo.
- [ ] Filter by meal type and cuisine.
- [ ] Open complete recipe details.
- [ ] Show allergen warnings for conflicts with the current user's selections.
- [ ] Add bounded loading or pagination if needed.
- [ ] Test filters, ordering, empty states, warnings, and unauthorized content access.

**Checkpoint 6 — Community beta:** Two test accounts can publish recipes, browse each other's public content, filter the feed, see correct warnings, and never see the other's private recipes.

### Phase 7: Hardening and release candidate

**Target: Weeks 7–8**

- [ ] Run the complete acceptance checklist against every functional requirement.
- [ ] Test representative physical devices and screen sizes.
- [ ] Address accessibility, keyboard behavior, image sizes, startup time, network failures, and offline messaging.
- [ ] Verify security rules and remove secrets and test credentials.
- [ ] Add appropriate crash and error diagnostics.
- [ ] Prepare demo accounts, a repeatable demo script, installation instructions, architecture notes, and known limitations.
- [ ] Freeze new features before final regression.

**Checkpoint 7 — Release candidate:** All must-have requirements pass; no critical/high defects remain; a clean install succeeds; the demo is repeatable; and denied permissions, failed recognition, no matches, and network loss have usable recovery paths.

## Team rhythm and definition of done

- Start each week by assigning a small set of requirements to an owner and reviewer.
- Integrate vertical slices early and demonstrate on a device midweek.
- End each week by recording checkpoint evidence and explicitly carrying unfinished work forward.
- Keep pull requests small; include tests and screenshots for UI changes.
- A task is done only when implemented, reviewed, tested, integrated, documented where needed, and demonstrated against its acceptance case.

## Decisions required before Phase 1 closes

1. Which platforms must the final demo support?
2. Is Firebase accepted by the course, or is another backend required?
3. Which recognition service is permitted, and what are its cost and privacy constraints?
4. Can guests scan and receive recommendations, or is sign-in required?
5. On account deletion, are authored public recipes deleted, anonymized, or retained?
6. Does “private recipe list” mean private recipes, saved recipes, or both?
7. Are allergen checks based only on author labels, or also derived from ingredients?
8. What image formats, size limits, and retention rules apply?
9. Is community content moderated or reportable in the MVP?
10. What is the delivery date so week numbers can become calendar dates?

## MVP scope guardrails

Defer social following, comments, ratings, chat, nutrition calculations, grocery ordering, meal calendars, advanced moderation, custom measurement conversion, and training a proprietary vision model unless explicitly required.

The highest technical risks are recognition accuracy, ingredient-name inconsistency, allergen safety, and authorization mistakes. Build thin experiments for these risks early.
