//
//  MLXWhisperTokenizer.swift
//  Vocorize
//
//  Tokenizer for MLX Whisper - handles text encoding/decoding
//

import Foundation

/// Whisper tokenizer for encoding text to tokens and decoding tokens to text
public class MLXWhisperTokenizer {

    // MARK: - Properties

    /// Token to ID mapping
    private var vocab: [String: Int] = [:]

    /// ID to token mapping
    private var idToToken: [Int: String] = [:]

    /// BPE merges
    private var bpeMerges: [(String, String)] = []

    /// BPE merge rankings
    private var bpeRanks: [String: Int] = [:]

    /// Special tokens
    public let eotToken: Int
    public let sotToken: Int
    public let translateToken: Int
    public let transcribeToken: Int
    public let noSpeechToken: Int
    public let noTimestampsToken: Int
    public let startOfPrevToken: Int
    public let startOfLmToken: Int

    /// Language tokens (offset from base)
    public let languageTokenOffset: Int

    /// Byte encoder for handling unicode
    private var byteEncoder: [Int: String] = [:]
    private var byteDecoder: [String: Int] = [:]

    // MARK: - Initialization

    public init(config: MLXWhisperConfig) {
        self.eotToken = config.eotToken
        self.sotToken = config.sotToken
        self.translateToken = config.translateToken
        self.transcribeToken = config.transcribeToken
        self.noSpeechToken = config.noSpeechToken
        self.noTimestampsToken = config.noTimestampsToken
        self.languageTokenOffset = config.langTokenOffset
        self.startOfPrevToken = 50361
        self.startOfLmToken = 50360

        // Initialize byte encoder
        initializeByteEncoder()
    }

    /// Load tokenizer from model directory
    public func load(from directory: URL) throws {
        // Try to load vocab.json
        let vocabURL = directory.appendingPathComponent("vocab.json")
        if FileManager.default.fileExists(atPath: vocabURL.path) {
            try loadVocab(from: vocabURL)
        }

        // Try to load merges.txt
        let mergesURL = directory.appendingPathComponent("merges.txt")
        if FileManager.default.fileExists(atPath: mergesURL.path) {
            try loadMerges(from: mergesURL)
        }

        // Try to load tokenizer.json (HuggingFace format)
        let tokenizerURL = directory.appendingPathComponent("tokenizer.json")
        if FileManager.default.fileExists(atPath: tokenizerURL.path) {
            try loadHuggingFaceTokenizer(from: tokenizerURL)
        }

        // Build reverse mapping
        for (token, id) in vocab {
            idToToken[id] = token
        }
    }

    // MARK: - Encoding

    /// Encode text to token IDs
    public func encode(_ text: String) -> [Int] {
        let normalizedText = normalizeText(text)
        let words = tokenizeWords(normalizedText)

        var tokens: [Int] = []
        for word in words {
            let wordTokens = bpeEncode(word)
            tokens.append(contentsOf: wordTokens)
        }

        return tokens
    }

    /// Get initial tokens for transcription
    public func getInitialTokens(language: String? = nil, task: String = "transcribe") -> [Int] {
        var tokens: [Int] = [sotToken]

        // Add language token if specified
        if let lang = language {
            if let langToken = languageToken(for: lang) {
                tokens.append(langToken)
            }
        }

        // Add task token
        if task == "translate" {
            tokens.append(translateToken)
        } else {
            tokens.append(transcribeToken)
        }

        // Add no timestamps token by default
        tokens.append(noTimestampsToken)

        return tokens
    }

    /// Get language token for language code
    public func languageToken(for code: String) -> Int? {
        // Whisper language codes mapping
        let languageCodes: [String: Int] = [
            "en": 0, "zh": 1, "de": 2, "es": 3, "ru": 4,
            "ko": 5, "fr": 6, "ja": 7, "pt": 8, "tr": 9,
            "pl": 10, "ca": 11, "nl": 12, "ar": 13, "sv": 14,
            "it": 15, "id": 16, "hi": 17, "fi": 18, "vi": 19,
            "he": 20, "uk": 21, "el": 22, "ms": 23, "cs": 24,
            "ro": 25, "da": 26, "hu": 27, "ta": 28, "no": 29,
            "th": 30, "ur": 31, "hr": 32, "bg": 33, "lt": 34,
            "la": 35, "mi": 36, "ml": 37, "cy": 38, "sk": 39,
            "te": 40, "fa": 41, "lv": 42, "bn": 43, "sr": 44,
            "az": 45, "sl": 46, "kn": 47, "et": 48, "mk": 49,
            "br": 50, "eu": 51, "is": 52, "hy": 53, "ne": 54,
            "mn": 55, "bs": 56, "kk": 57, "sq": 58, "sw": 59,
            "gl": 60, "mr": 61, "pa": 62, "si": 63, "km": 64,
            "sn": 65, "yo": 66, "so": 67, "af": 68, "oc": 69,
            "ka": 70, "be": 71, "tg": 72, "sd": 73, "gu": 74,
            "am": 75, "yi": 76, "lo": 77, "uz": 78, "fo": 79,
            "ht": 80, "ps": 81, "tk": 82, "nn": 83, "mt": 84,
            "sa": 85, "lb": 86, "my": 87, "bo": 88, "tl": 89,
            "mg": 90, "as": 91, "tt": 92, "haw": 93, "ln": 94,
            "ha": 95, "ba": 96, "jw": 97, "su": 98, "yue": 99
        ]

        if let offset = languageCodes[code.lowercased()] {
            return languageTokenOffset + offset
        }
        return nil
    }

    // MARK: - Decoding

    /// Decode token IDs to text
    public func decode(_ tokens: [Int]) -> String {
        var text = ""

        for token in tokens {
            // Skip special tokens
            if token >= sotToken {
                continue
            }

            if let tokenStr = idToToken[token] {
                text += tokenStr
            }
        }

        // Decode byte-encoded characters
        return decodeBytePairs(text)
    }

    /// Decode token IDs, skipping special tokens
    public func decodeWithoutSpecialTokens(_ tokens: [Int]) -> String {
        let filteredTokens = tokens.filter { token in
            // Filter out special tokens (typically > 50256)
            return token < 50257
        }
        return decode(filteredTokens)
    }

    // MARK: - Private Methods

    /// Initialize byte encoder for unicode handling
    private func initializeByteEncoder() {
        var bs: [Int] = []

        // Printable ASCII range
        for i in Int(Character("!").asciiValue!)...Int(Character("~").asciiValue!) {
            bs.append(i)
        }

        // Extended ASCII range
        for i in Int(Character("¡").asciiValue ?? 161)...Int(Character("¬").asciiValue ?? 172) {
            bs.append(i)
        }
        for i in Int(Character("®").asciiValue ?? 174)...Int(Character("ÿ").asciiValue ?? 255) {
            bs.append(i)
        }

        var cs = bs.map { $0 }
        var n = 0
        for b in 0..<256 {
            if !bs.contains(b) {
                bs.append(b)
                cs.append(256 + n)
                n += 1
            }
        }

        for (b, c) in zip(bs, cs) {
            byteEncoder[b] = String(UnicodeScalar(c)!)
            byteDecoder[String(UnicodeScalar(c)!)] = b
        }
    }

    /// Load vocabulary from vocab.json
    private func loadVocab(from url: URL) throws {
        let data = try Data(contentsOf: url)
        vocab = try JSONDecoder().decode([String: Int].self, from: data)
    }

    /// Load BPE merges from merges.txt
    private func loadMerges(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        bpeMerges = []
        for (index, line) in lines.enumerated() {
            // Skip header line
            if line.hasPrefix("#") || line.isEmpty {
                continue
            }

            let parts = line.split(separator: " ")
            if parts.count == 2 {
                let merge = (String(parts[0]), String(parts[1]))
                bpeMerges.append(merge)
                bpeRanks["\(merge.0) \(merge.1)"] = index
            }
        }
    }

    /// Load tokenizer from HuggingFace tokenizer.json format
    private func loadHuggingFaceTokenizer(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Extract vocab from model
        if let model = json["model"] as? [String: Any] {
            if let vocabDict = model["vocab"] as? [String: Int] {
                vocab = vocabDict
            }

            if let merges = model["merges"] as? [String] {
                bpeMerges = []
                for (index, merge) in merges.enumerated() {
                    let parts = merge.split(separator: " ")
                    if parts.count == 2 {
                        let mergePair = (String(parts[0]), String(parts[1]))
                        bpeMerges.append(mergePair)
                        bpeRanks[merge] = index
                    }
                }
            }
        }

        // Extract added tokens
        if let addedTokens = json["added_tokens"] as? [[String: Any]] {
            for tokenInfo in addedTokens {
                if let content = tokenInfo["content"] as? String,
                   let id = tokenInfo["id"] as? Int {
                    vocab[content] = id
                }
            }
        }
    }

    /// Normalize text for tokenization
    private func normalizeText(_ text: String) -> String {
        // Basic normalization
        var normalized = text.lowercased()

        // Normalize unicode
        normalized = normalized.precomposedStringWithCanonicalMapping

        // Normalize whitespace
        let whitespaceRegex = try? NSRegularExpression(pattern: "\\s+", options: [])
        normalized = whitespaceRegex?.stringByReplacingMatches(
            in: normalized,
            options: [],
            range: NSRange(normalized.startIndex..., in: normalized),
            withTemplate: " "
        ) ?? normalized

        return normalized.trimmingCharacters(in: .whitespaces)
    }

    /// Tokenize text into words with spacing markers
    private func tokenizeWords(_ text: String) -> [String] {
        // Split on whitespace, keeping track of word boundaries
        var words: [String] = []
        let components = text.components(separatedBy: " ")

        for (index, word) in components.enumerated() {
            if word.isEmpty { continue }

            // Add space prefix for all words except first
            if index > 0 {
                words.append("Ġ" + word)  // Ġ is the GPT-2 space token
            } else {
                words.append(word)
            }
        }

        return words
    }

    /// BPE encode a single word
    private func bpeEncode(_ word: String) -> [Int] {
        if word.isEmpty { return [] }

        // Convert word to BPE-ready format
        var tokens = word.map { String($0) }

        // Apply BPE merges
        while tokens.count > 1 {
            var bestMerge: (Int, Int)? = nil
            var bestRank = Int.max

            // Find the highest priority merge
            for i in 0..<(tokens.count - 1) {
                let pair = "\(tokens[i]) \(tokens[i + 1])"
                if let rank = bpeRanks[pair], rank < bestRank {
                    bestRank = rank
                    bestMerge = (i, i + 1)
                }
            }

            // If no merge found, we're done
            guard let merge = bestMerge else { break }

            // Apply the merge
            let newToken = tokens[merge.0] + tokens[merge.1]
            tokens.remove(at: merge.1)
            tokens[merge.0] = newToken
        }

        // Convert tokens to IDs
        return tokens.compactMap { vocab[$0] }
    }

    /// Decode byte-pair encoded string back to unicode
    private func decodeBytePairs(_ text: String) -> String {
        var bytes: [UInt8] = []

        for char in text {
            let charStr = String(char)
            if let byte = byteDecoder[charStr] {
                bytes.append(UInt8(byte))
            } else if let ascii = char.asciiValue {
                bytes.append(ascii)
            }
        }

        // Handle the special space token
        var result = String(bytes: bytes, encoding: .utf8) ?? text
        result = result.replacingOccurrences(of: "Ġ", with: " ")

        return result.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Errors

public enum MLXWhisperTokenizerError: LocalizedError {
    case vocabNotLoaded
    case invalidTokenizerFormat
    case fileNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .vocabNotLoaded:
            return "Tokenizer vocabulary not loaded"
        case .invalidTokenizerFormat:
            return "Invalid tokenizer file format"
        case .fileNotFound(let path):
            return "Tokenizer file not found: \(path)"
        }
    }
}
