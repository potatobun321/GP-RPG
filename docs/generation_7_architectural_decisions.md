# Generation 7 Architectural Decisions

This document maintains a chronological record of accepted architectural decisions.

---

**Decision:** Presets Own Vocabulary
**Reason:** Prevent central vocabulary authority, ensuring GP-RPG remains a framework for custom dialects rather than a rigid engine.
**Date:** Generation 7
**Status:** Accepted

---

**Decision:** Generic Contract Validation
**Reason:** The engine must enforce consistency (Tokens requiring Attributes) without ever understanding the gameplay meaning of those Tokens.
**Date:** Generation 7
**Status:** Accepted

---

**Decision:** Vocabulary Mutation over Boolean Checks
**Reason:** To handle state changes (like spent triggers), entities simply overwrite their own Composite identities rather than systems relying on internal `if/else` flags.
**Date:** Generation 7
**Status:** Accepted

---

**Decision:** Defer Dynamic System Loading
**Reason:** To avoid premature optimization, all systems load universally until real performance or maintenance issues necessitate dynamic loading.
**Date:** Generation 7
**Status:** Accepted
