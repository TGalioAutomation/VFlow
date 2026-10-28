import Foundation

/// Detects English words, phonotactic structures, and bilingual context for real-time and on-space Auto-English Restore.
public struct SmartEnglishDetector: Sendable {
    /// Unambiguous English vocabulary (programming, OS, web, and everyday English words that do NOT collide with common Vietnamese words).
    public static let commonEnglishWords: Set<String> = [
        // OS, Web & Tech
        "window", "windows", "safari", "chrome", "firefox", "browser",
        "react", "vue", "angular", "svelte", "swift", "swiftui", "macos", "apple",
        "function", "func", "status", "const", "import", "export", "service", "server",
        "class", "struct", "enum", "let", "var", "if", "of", "type", "protocol", "actor",
        "string", "number", "boolean", "bool", "int", "float", "double",
        "return", "default", "interface", "component", "props", "state", "hook",
        "async", "await", "promise", "future", "task", "thread", "queue",
        "null", "nil", "undefined", "true", "false", "void", "any", "object",
        "public", "private", "fileprivate", "internal", "protected", "static",
        "self", "this", "super", "init", "new", "delete", "create", "update",
        "guard", "defer", "repeat", "while", "for", "in", "break", "continue",
        "switch", "case", "fallthrough", "where", "catch", "throw", "throws",
        "print", "console", "log", "error", "warn", "info", "debug", "trace",
        "screen", "cursor", "mouse", "keyboard", "event", "input", "output",
        "click", "tap", "hover", "scroll", "focus", "blur", "submit", "change",
        "google", "facebook", "meta", "zalo", "telegram", "slack", "discord",
        "code", "commit", "branch", "merge", "push", "pull", "checkout", "fetch",
        "clone", "reset", "rebase", "stash", "diff", "tag", "patch", "remote",
        "build", "test", "run", "start", "stop", "restart", "deploy", "release",
        "docker", "compose", "container", "image", "volume", "network", "port",
        "host", "user", "users", "username", "password", "token", "secret", "auth", "session",
        "query", "mutation", "subscription", "schema", "table", "column",
        "select", "insert", "from", "join", "left", "right", "inner", "outer",
        "group", "order", "by", "having", "limit", "offset", "count", "sum",
        "view", "button", "label", "text", "icon", "color", "style",
        "background", "border", "padding", "margin", "width", "height", "size",
        "font", "weight", "bold", "italic", "center", "flex", "grid", "gap",
        "opacity", "shadow", "radius", "corner", "frame", "bounds", "point", "rect",
        "app", "process", "main", "global", "sync", "dispatch", "timer", "delay",
        "url", "uri", "http", "https", "request", "response", "header", "body",
        "json", "xml", "yaml", "html", "css", "api", "rest", "graphql", "socket",
        "client", "cloud", "local", "file", "path", "folder", "directory",
        "open", "close", "read", "write", "save", "load", "clear",
        "viewcontroller", "activity", "fragment", "broadcast",
        "setup", "config", "setting", "settings", "option", "options", "preference",
        "profile", "account", "home", "search", "filter", "sort", "category",
        "item", "list", "array", "map", "set", "dictionary", "record", "tuple",
        "find", "index", "first", "last", "length", "pop",
        "shift", "unshift", "splice", "slice", "split", "concat",
        "reduce", "foreach", "some", "every", "includes",
        "target", "source", "dest", "destination", "param", "params", "arg", "args",
        "result", "value", "key", "pair", "entry", "entries", "items",
        // Common Bilingual & Everyday English Words
        "english", "vietnamese", "support", "feature", "features", "system", "systems",
        "project", "projects", "message", "messages", "version", "versions",
        "world", "work", "works", "working", "worker", "word", "words",
        "time", "times", "go", "goes", "going", "ready",
        "with", "without", "within", "what", "when", "which", "who", "why", "whose",
        "web", "website", "week", "well", "will", "win", "want", "way", "water",
        "hello", "morning", "meeting", "today", "tomorrow", "yesterday",
        "developer", "company", "product", "email", "phone", "address", "customer",
        "manager", "report", "document", "download", "upload", "install",
        "database", "security", "performance", "model", "models", "agent", "agents",
        "post", "posts", "cost", "costs", "fast", "past", "just", "must", "best", "rest",
        "part", "parts", "cart", "dart", "hurt", "dirt", "shirt", "short", "sport",
        "form", "forms", "term", "terms", "firm", "warm", "worm", "storm", "farm",
        "born", "corn", "horn", "torn", "warn", "learn", "turn", "burn",
        "next", "context", "syntax", "linux", "unix", "redux", "flux",
        "soft", "gift", "lift", "draft", "craft", "left",
        "task", "tasks", "mask", "desk", "risk", "disk", "mark", "dark", "park", "fork",
        "card", "hard", "ward", "lord", "cord", "bird", "third", "board", "guard",
        "plus", "bonus", "minus", "virus", "campus", "always", "sometimes", "perhaps",
        "few", "review", "preview", "interview", "overview",
        "raw", "saw", "law", "paw", "thaw", "draw", "flaw", "claw", "straw",
        "show", "know", "grow", "flow", "slow", "allow", "follow", "yellow", "shadow", "arrow",
        "more", "core", "store", "before", "restore", "ignore", "explore",
        "here", "there", "were", "care", "share", "software", "hardware",
        "fire", "wire", "hire", "tire", "require", "entire", "desire",
        "sure", "pure", "cure", "secure", "ensure", "measure", "nature", "culture",
        "picture", "structure", "architecture", "lecture", "capture",
        "use", "using", "used", "useful", "music", "basic", "design",
        "base", "phase", "chase", "lease", "please",
        "house", "mouse", "cause", "because", "course", "nurse", "horse", "force",
        "else", "sense", "license", "rise", "wise", "size", "prize",
        "safe", "life", "wife", "knife", "cafe", "coffee", "office", "surface",
        "editor", "monitor", "doctor", "factor", "vector", "sector", "director",
        "selector", "detector", "constructor", "generator", "operator", "validator",
        "iterator", "sensor", "processor", "senior", "junior", "prior", "behavior",
        "member", "footer", "render", "helper", "router", "buffer", "driver",
        "listener", "handler", "controller", "compiler", "parser", "tester", "builder",
        "runner", "logger", "adapter", "wrapper", "mapper", "observer", "consumer",
        "producer", "sender", "receiver", "counter", "pointer", "register", "parameter",
        "character", "integer", "master", "cluster", "enter", "after", "under", "over",
        "never", "ever", "other", "another", "paper", "letter", "better", "matter",
        "later", "layer", "player", "power", "tower", "lower", "higher", "faster",
        "slower", "smaller", "larger", "longer", "shorter", "cleaner", "clearer",
        "easier", "harder", "stronger", "newer", "older", "closer", "further",
        "super", "summer", "winter", "dinner", "winner", "banner", "scanner", "planner",
        "owner", "partner", "teacher", "answer", "border", "radar", "guitar", "sugar",
        "solar", "regular", "popular", "similar", "particular", "modular", "circular",
        "linear", "nuclear", "clear", "near", "year", "hear", "fear", "dear", "gear",
        "tear", "wear", "bear", "appear", "calendar", "dollar", "grammar",
        "root", "boot", "loop", "hoop", "coop", "meet", "beet", "keep", "deep",
        "need", "seed", "feed", "feel", "heel", "week", "seek", "book", "look",
        "took", "cook", "hook", "good", "food", "mood", "wood", "cool", "tool", "pool", "school",
        "down", "town", "door", "poor", "major", "floor", "brown", "clown", "dust",
        "def", "ref"
    ]

    /// Short English words whose raw Telex keystrokes collide with valid Vietnamese words (e.g. "car" -> "cả", "bow" -> "bơ").
    /// These are only restored to English when the preceding word in the sentence was English (`previousWordWasEnglish == true`).
    public static let contextualEnglishHomographs: Set<String> = [
        "car", "bar", "tar", "char",
        "or", "nor", "her", "per",
        "is", "as", "us", "his", "has", "was", "bus", "thus",
        "now", "how", "low", "row", "bow", "cow", "tow", "mow", "sow",
        "box", "tax", "max", "mix", "six", "fix",
        "cast", "mast", "vast", "lost", "most", "rust", "vest"
    ]

    /// Impossible Vietnamese syllable initial consonant clusters.
    private static let invalidVietnameseInitials = [
        "str", "scr", "spl", "spr", "shr", "thr", "chr", "phr", "sch",
        "fl", "gl", "cl", "bl", "pl", "sl",
        "br", "cr", "dr", "fr", "gr", "pr", "wr", "wh", "sh",
        "ps", "pn", "gn", "kn", "sm", "sn", "sp", "st", "sk", "sc", "sw", "tw", "dw", "gw", "qw"
    ]

    /// Substrings (double consonants or English vowel digraphs) that NEVER appear in valid Vietnamese Telex words.
    /// Note: "sh" is NOT included here because in free-order Telex, "-nsh" / "-csh" occurs when typing "đánh" ("ddansh") or "cách" ("casch").
    private static let englishOnlySubstrings = [
        "ss", "ff", "rr", "ll", "pp", "tt", "bb", "gg", "mm", "cc", "zz", "ck",
        "ea", "ou", "io", "ya", "yo", "yu", "yi"
    ]

    /// Genuine English words or stems containing "rr", "ss", or "ff" that should preserve both consonants
    /// rather than collapsing as a UniKey-style Telex tone escape (unlike "arr"->"ar", "arry"->"ary", "ayrr"->"ayr", "toanss"->"toans").
    private static let genuineDoubleConsonantStems: [String] = [
        // Genuine "rr" stems & words (excluding "arr" and "arry" which are Telex escapes for "ar" / "ary")
        "arra", "arre", "arri", "arro", "err", "carr", "marr", "harr", "parr", "tarr", "starr", "quarr",
        "berr", "cherr", "ferr", "merr", "jerr", "terr", "perr", "sorr", "worr", "lorr", "hurr", "flurr",
        "curr", "furr", "blurr", "slurr", "scurr", "corr", "overr", "mirr", "horr", "borr", "tomorr",
        "narr", "marrow", "sparr", "barr", "warr", "torr", "surr", "interr", "irr", "referr", "occurr",
        "preferr", "transferr", "inferr", "deferr", "conferr", "deterr", "burr",
        // Genuine "ss" stems & words
        "pass", "mass", "bass", "class", "glass", "grass", "brass", "boss", "loss", "toss", "moss",
        "cross", "floss", "gloss", "across", "less", "mess", "chess", "bless", "guess", "press", "dress",
        "stress", "express", "impress", "depress", "compress", "suppress", "oppress", "repress",
        "address", "progress", "congress", "success", "access", "process", "excess", "recess",
        "assess", "possess", "obsess", "confess", "profess", "kiss", "miss", "hiss", "bliss", "swiss",
        "abyss", "dismiss", "fuss", "discuss", "session", "passion", "mission", "permission", "commission",
        "submission", "transmission", "admission", "omission", "emission", "issue", "tissue", "fissure",
        "pressure", "assure", "assurance", "reassure", "assign", "assist", "assume", "assumption",
        "assert", "assertion", "asset", "associate", "association", "assemble", "assembly", "assault",
        "essential", "essence", "essay", "message", "messenger", "passage", "passenger", "massage",
        "possible", "possibly", "possibility", "impossible", "necessary", "unnecessary", "ambassador",
        "embassy", "embarrass", "harass", "professor", "professional", "processor", "classic", "classify",
        "classification", "classroom", "password", "passport", "passive", "massive", "aggressive",
        "progressive", "impressive", "expressive", "excessive", "lesson", "vessel", "fossil", "gossip",
        "blossom", "possum", "russian", "cassette", "chassis", "dossier", "dessert", "ness",
        // Genuine "ff" stems & words
        "off", "iff", "diff", "buff", "cuff", "puff", "muff", "ruff", "bluff", "fluff", "scuff", "snuff",
        "stuff", "staff", "stiff", "cliff", "whiff", "skiff", "sniff", "sheriff", "tariff", "plaintiff",
        "bailiff", "suffer", "effe", "affe", "effo", "affo", "affa", "affi", "affl", "afflu", "coff",
        "toff", "muffin", "puffin", "baffl", "raffl", "waffl", "shuffl", "truffl", "scuffl", "muffl",
        "duffel", "traff", "scaff", "giraff", "graff", "suffix", "effic", "suffic", "defic", "coeffic", "profic"
    ]

    /// Returns `true` if `rawWord` containing `rr`, `ss`, or `ff` is a genuine English word/stem rather than a Telex tone escape.
    public static func isGenuineEnglishDoubleConsonantWord(_ rawWord: String) -> Bool {
        let clean = rawWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.count >= 3 else { return false }

        // 1. Starts with non-Vietnamese initial or English-only initial cluster
        if let first = clean.first, ["f", "j", "z", "w"].contains(first) {
            return true
        }
        for initial in invalidVietnameseInitials {
            if clean.hasPrefix(initial) {
                return true
            }
        }

        // 2. Contains other non-Telex English double letters or vowel digraphs
        let otherEnglishMarkers = ["ll", "pp", "tt", "bb", "gg", "mm", "cc", "zz", "ck", "ea", "ou", "io"]
        for marker in otherEnglishMarkers {
            if clean.contains(marker) {
                return true
            }
        }

        // 3. Direct dictionary or stem match (including inflected compound forms like bypassing, keypresses, subclasses)
        if commonEnglishWords.contains(clean) {
            return true
        }
        var strippedBase = clean
        for suffix in ["ing", "es", "ed", "er", "ers", "ly", "s"] {
            if strippedBase.count > suffix.count + 3 && strippedBase.hasSuffix(suffix) {
                strippedBase = String(strippedBase.dropLast(suffix.count))
                break
            }
        }
        for stem in genuineDoubleConsonantStems {
            if clean == stem || clean.hasPrefix(stem) || clean.hasSuffix(stem) ||
               strippedBase == stem || strippedBase.hasSuffix(stem) ||
               clean.hasSuffix("ness") || clean.hasSuffix("less") || clean.hasSuffix("ssion") {
                return true
            }
        }

        return false
    }

    /// Detects when a Telex tone key ('s', 'f', 'r', 'x', 'j') is placed between two plain vowels in a word
    /// without unambiguous Vietnamese modifiers ('aa', 'ee', 'oo', 'dd', 'w'), such as "ary", "ory", "ery", "ury",
    /// "are", "ore", "ere", "ure", "ire", "use", "base", "safe", "easy", "busy", "major", "axis", "query", "vary", "diary".
    public static func hasIntervocalicTelexToneInUnmodifiedWord(_ clean: String) -> Bool {
        guard clean.count >= 3 else { return false }
        let hasUnambiguousTelexMarkers = clean.contains("ee") || clean.contains("oo") ||
            clean.contains("aa") || clean.contains("dd") || clean.contains("w")
        if hasUnambiguousTelexMarkers {
            return false
        }

        let chars = Array(clean)
        let plainVowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        let telexToneChars: Set<Character> = ["s", "f", "r", "x", "j"]

        // Skip initial consonant cluster (including 'qu' or 'gi' when followed by a vowel)
        var startIdx = 0
        if chars.count >= 3 && ((chars[0] == "q" && chars[1] == "u") || (chars[0] == "g" && chars[1] == "i")) && plainVowels.contains(chars[2]) {
            startIdx = 2
        } else {
            while startIdx < chars.count && !plainVowels.contains(chars[startIdx]) {
                startIdx += 1
            }
        }

        guard startIdx + 2 < chars.count else { return false }
        for idx in (startIdx + 1)..<(chars.count - 1) {
            if telexToneChars.contains(chars[idx]) &&
               plainVowels.contains(chars[idx - 1]) &&
               plainVowels.contains(chars[idx + 1]) {
                return true
            }
        }
        return false
    }

    /// Impossible Vietnamese syllable end patterns (excluding any valid Vietnamese final + Telex tone key like ts, ps, ns, nx, tz, dd, nsh, csh).
    private static let invalidVietnameseEndings = [
        "ct", "nd", "rt", "st", "ft", "lt", "mp", "nt", "pt", "sk", "sp",
        "rk", "rm", "rn", "lp", "lk", "rd", "ld", "lm", "ln", "lv",
        "mb", "mn", "nk", "rb", "rc", "rg", "rl", "rp",
        "rv", "rz", "sc", "sm", "sn", "ss", "tc", "xt", "zz",
        "ff", "gg", "bb", "ll", "mm", "pp", "tt"
    ]

    /// Fast real-time check while typing a word: returns `true` if `rawWord` is guaranteed to be English (never Vietnamese).
    public static func isDefinitelyEnglishInProgress(_ rawWord: String) -> Bool {
        let clean = rawWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return false }

        // 1. Starts with non-Vietnamese initial letters: f, j, z
        if let first = clean.first, ["f", "j", "z"].contains(first) {
            return true
        }

        // 2. Starts with 'w' followed by any letter (except 2-letter shorthand ws, wf, wr, wx, wj for ứ, ừ, ử, ữ, ự)
        if clean.first == "w" && clean.count >= 2 {
            let validWShortHands: Set<String> = ["ws", "wf", "wr", "wx", "wj"]
            if !validWShortHands.contains(clean) {
                return true
            }
        }

        // 3. Starts with an English-only consonant cluster (st, sp, cl, cr, br, pr, fl, fr, gr, pl, sl, sm, sn, sk, sc, sw, tw, wh, wr, sh...)
        for initial in invalidVietnameseInitials {
            if clean.hasPrefix(initial) {
                return true
            }
        }

        // 4. Contains English-only double consonants or vowel digraphs (ss, ff, rr, ll, pp, tt, ck, ea, ou, io, ya, yo...)
        for sub in englishOnlySubstrings {
            if clean.contains(sub) {
                return true
            }
        }

        // 5. Contains an intervocalic Telex tone key ('s', 'f', 'r', 'x', 'j') between two plain vowels
        // in an unmodified word (e.g. "ary", "ory", "ery", "ury", "are", "use", "base", "safe", "easy", "busy", "vary", "diary")
        if hasIntervocalicTelexToneInUnmodifiedWord(clean) {
            return true
        }

        return false
    }

    /// Checks if a completed word (raw typed string) matches English heuristics or vocabulary.
    public static func isEnglishWord(_ word: String, previousWordWasEnglish: Bool = false) -> Bool {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.count >= 2 else { return false }

        // 1. Fast in-progress checks also apply to completed words
        if isDefinitelyEnglishInProgress(clean) {
            return true
        }

        // 2. Direct unambiguous dictionary match
        if commonEnglishWords.contains(clean) {
            return true
        }

        // 3. Contextual English homograph match when the user is already typing an English phrase
        if previousWordWasEnglish && contextualEnglishHomographs.contains(clean) {
            return true
        }

        // 4. Final consonant cluster violation (excluding free-order Telex and unambiguous Vietnamese markers)
        let isFreeOrderTelex: Bool = {
            let chars = Array(clean)
            guard chars.count >= 3 else { return false }
            let penultimate = chars[chars.count - 2]
            let last = chars[chars.count - 1]
            let beforePenultimate = chars[chars.count - 3]
            let isTelexTone = ["s", "f", "r", "x", "j"].contains(penultimate)
            let isFinalConsonant = ["t", "n", "c", "m", "p"].contains(last)
            let hasVowelBefore = VietnameseVowelMap.isVowel(beforePenultimate)
            return isTelexTone && isFinalConsonant && hasVowelBefore
        }()

        let hasUnambiguousTelexMarkers = clean.contains("ee") || clean.contains("oo") ||
            clean.contains("aa") || clean.contains("dd") || clean.contains("w")

        if !isFreeOrderTelex && !hasUnambiguousTelexMarkers {
            for ending in invalidVietnameseEndings {
                if clean.hasSuffix(ending) {
                    return true
                }
            }
        }

        return false
    }
}
