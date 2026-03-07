//
//  HTMLContentParser.swift
//  PIRATEN
//
//  Created by Claude Code on 03.02.26.
//

import Foundation
import SwiftUI

/// Utility for parsing HTML content into AttributedString with clickable links.
/// Used to render forum posts and messages with preserved hyperlinks.
enum HTMLContentParser {

    /// Parses HTML content and returns an AttributedString with clickable links.
    /// Falls back to plain text if parsing fails.
    /// - Parameter html: The HTML string to parse
    /// - Returns: AttributedString with links, or plain text fallback
    static func parseToAttributedString(_ html: String) -> AttributedString {
        let processed = replaceEmojiShortcodes(in: html)
        // First, try to parse as HTML to get an attributed string with links
        if let attributedString = parseHTML(processed) {
            return attributedString
        }

        // Fallback: strip HTML and return plain text
        return AttributedString(stripHTML(from: processed))
    }

    /// Attempts to parse HTML into an AttributedString using NSAttributedString.
    /// This preserves links and converts them to tappable links in SwiftUI.
    /// Strips hardcoded foreground colors so SwiftUI's `.foregroundColor(.primary)`
    /// can take effect, ensuring legibility in both light and dark mode.
    private static func parseHTML(_ html: String) -> AttributedString? {
        // Wrap in basic HTML structure for proper parsing
        let wrappedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
        body { font-family: -apple-system; font-size: 17px; }
        a { color: #007AFF; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """

        guard let data = wrappedHTML.data(using: .utf8) else {
            return nil
        }

        // Parse HTML on main thread (required for NSAttributedString HTML parsing)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let nsAttributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }

        // Strip hardcoded foreground colors from non-link text.
        // NSAttributedString HTML parsing bakes in black text color, which is
        // invisible on dark backgrounds. By removing foregroundColor from runs
        // that aren't links, SwiftUI's .foregroundColor(.primary) takes effect.
        var attributed = AttributedString(nsAttributedString)
        for run in attributed.runs {
            let hasLink = run.link != nil
            if !hasLink {
                attributed[run.range].uiKit.foregroundColor = nil
            }
        }
        return attributed
    }

    /// Strips HTML tags from content, preserving only plain text.
    /// Also decodes common HTML entities and emoji shortcodes.
    static func stripHTML(from htmlString: String) -> String {
        let stripped = replaceEmojiShortcodes(in: htmlString)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#x2F;", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return stripped
    }

    /// Extracts image URLs from HTML `<img>` tags, excluding emoji images.
    /// - Parameter html: The HTML string to extract images from
    /// - Returns: Array of image URLs found in the HTML
    static func extractImageURLs(from html: String) -> [URL] {
        // Match <img> tags that are NOT emoji (no class="emoji")
        let pattern = #"<img\s+(?![^>]*class\s*=\s*"[^"]*emoji)[^>]*src\s*=\s*"([^"]+)"[^>]*/?\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        return matches.compactMap { match in
            guard let srcRange = Range(match.range(at: 1), in: html) else { return nil }
            let src = String(html[srcRange])
            if src.contains("emoji") { return nil }
            return URL(string: src)
        }
    }

    /// Replaces Discourse emoji `<img>` tags and `:shortcode:` text with Unicode emojis.
    static func replaceEmojiShortcodes(in text: String) -> String {
        var result = text

        // Replace Discourse <img class="emoji" title=":name:" ...> tags with the emoji
        result = result.replacingOccurrences(
            of: #"<img[^>]*class="emoji"[^>]*title=":([^"]+):"[^>]*/?\s*>"#,
            with: ":$1:",
            options: .regularExpression
        )
        // Also handle reversed attribute order
        result = result.replacingOccurrences(
            of: #"<img[^>]*title=":([^"]+):"[^>]*class="emoji"[^>]*/?\s*>"#,
            with: ":$1:",
            options: .regularExpression
        )

        // Replace :shortcode: with Unicode emoji
        for (shortcode, emoji) in emojiMap {
            result = result.replacingOccurrences(of: ":\(shortcode):", with: emoji)
        }

        return result
    }

    // swiftlint:disable:next line_length
    /// Common Discourse emoji shortcodes mapped to Unicode.
    private static let emojiMap: [String: String] = [
        // Smileys & People
        "smile": "😄", "laughing": "😆", "blush": "😊", "smiley": "😃",
        "relaxed": "☺️", "smirk": "😏", "heart_eyes": "😍", "kissing_heart": "😘",
        "kissing_closed_eyes": "😚", "flushed": "😳", "relieved": "😌", "satisfied": "😆",
        "grin": "😁", "wink": "😉", "stuck_out_tongue_winking_eye": "😜",
        "stuck_out_tongue_closed_eyes": "😝", "grinning": "😀", "kissing": "😗",
        "kissing_smiling_eyes": "😙", "stuck_out_tongue": "😛", "sleeping": "😴",
        "worried": "😟", "frowning": "😦", "anguished": "😧", "open_mouth": "😮",
        "grimacing": "😬", "confused": "😕", "hushed": "😯", "expressionless": "😑",
        "unamused": "😒", "sweat_smile": "😅", "sweat": "😓",
        "disappointed_relieved": "😥", "weary": "😩", "pensive": "😔", "disappointed": "😞",
        "confounded": "😖", "fearful": "😨", "cold_sweat": "😰", "persevere": "😣",
        "cry": "😢", "sob": "😭", "joy": "😂", "astonished": "😲",
        "scream": "😱", "tired_face": "😫", "angry": "😠", "rage": "😡",
        "triumph": "😤", "sleepy": "😪", "yum": "😋", "mask": "😷",
        "sunglasses": "😎", "dizzy_face": "😵", "imp": "👿", "smiling_imp": "😈",
        "neutral_face": "😐", "no_mouth": "😶", "innocent": "😇", "alien": "👽",
        "yellow_heart": "💛", "blue_heart": "💙", "purple_heart": "💜", "heart": "❤️",
        "green_heart": "💚", "broken_heart": "💔", "heartbeat": "💓", "heartpulse": "💗",
        "two_hearts": "💕", "revolving_hearts": "💞", "cupid": "💘", "sparkling_heart": "💖",
        "sparkles": "✨", "star": "⭐", "star2": "🌟", "dizzy": "💫",
        "boom": "💥", "collision": "💥", "anger": "💢", "exclamation": "❗",
        "question": "❓", "grey_exclamation": "❕", "grey_question": "❔",
        "zzz": "💤", "dash": "💨", "sweat_drops": "💦", "notes": "🎶",
        "musical_note": "🎵", "fire": "🔥", "poop": "💩",
        "thumbsup": "👍", "+1": "👍", "thumbsdown": "👎", "-1": "👎",
        "ok_hand": "👌", "punch": "👊", "fist": "✊", "v": "✌️",
        "wave": "👋", "hand": "✋", "raised_hand": "✋", "open_hands": "👐",
        "point_up": "☝️", "point_down": "👇", "point_left": "👈", "point_right": "👉",
        "raised_hands": "🙌", "pray": "🙏", "point_up_2": "👆", "clap": "👏",
        "muscle": "💪", "metal": "🤘", "fu": "🖕",
        "walking": "🚶", "runner": "🏃", "running": "🏃", "couple": "👫",
        "family": "👪", "two_men_holding_hands": "👬", "two_women_holding_hands": "👭",
        "dancer": "💃", "bow": "🙇", "couplekiss": "💏", "couple_with_heart": "💑",
        "no_good": "🙅", "ok_woman": "🙆", "raising_hand": "🙋",
        "person_with_pouting_face": "🙎", "person_frowning": "🙍", "haircut": "💇",
        "massage": "💆", "skull": "💀", "ghost": "👻",
        "eyes": "👀", "eye": "👁️", "tongue": "👅", "lips": "👄",
        "kiss": "💋", "baby": "👶", "boy": "👦", "girl": "👧",
        "man": "👨", "woman": "👩", "older_man": "👴", "older_woman": "👵",
        "cop": "👮", "guardsman": "💂", "angel": "👼", "princess": "👸",
        "robot": "🤖", "nerd_face": "🤓",
        "slightly_smiling_face": "🙂", "slightly_frowning_face": "🙁",
        "upside_down_face": "🙃", "rolling_eyes": "🙄", "thinking": "🤔",
        "zipper_mouth_face": "🤐", "face_with_thermometer": "🤒",
        "face_with_head_bandage": "🤕", "money_mouth_face": "🤑",
        "hugs": "🤗", "crossed_fingers": "🤞", "handshake": "🤝",
        "rofl": "🤣", "face_palm": "🤦", "shrug": "🤷",
        "face_with_monocle": "🧐", "partying_face": "🥳",
        "pleading_face": "🥺", "yawning_face": "🥱",

        // Nature
        "sunny": "☀️", "umbrella": "☂️", "cloud": "☁️", "snowflake": "❄️",
        "snowman": "⛄", "zap": "⚡", "cyclone": "🌀", "foggy": "🌁",
        "ocean": "🌊", "cat": "🐱", "dog": "🐶", "mouse": "🐭",
        "hamster": "🐹", "rabbit": "🐰", "wolf": "🐺", "frog": "🐸",
        "tiger": "🐯", "koala": "🐨", "bear": "🐻", "pig": "🐷",
        "cow": "🐮", "boar": "🐗", "monkey_face": "🐵", "monkey": "🐒",
        "horse": "🐴", "racehorse": "🐎", "camel": "🐫", "sheep": "🐑",
        "elephant": "🐘", "snake": "🐍", "bird": "🐦", "chick": "🐤",
        "penguin": "🐧", "bug": "🐛", "octopus": "🐙", "turtle": "🐢",
        "fish": "🐟", "whale": "🐳", "dolphin": "🐬", "snail": "🐌",
        "rose": "🌹", "sunflower": "🌻", "tulip": "🌷", "seedling": "🌱",
        "evergreen_tree": "🌲", "deciduous_tree": "🌳", "palm_tree": "🌴",
        "cactus": "🌵", "fallen_leaf": "🍂", "maple_leaf": "🍁",
        "mushroom": "🍄", "four_leaf_clover": "🍀", "cherry_blossom": "🌸",
        "bouquet": "💐", "earth_africa": "🌍", "earth_americas": "🌎",
        "earth_asia": "🌏", "full_moon": "🌕", "new_moon": "🌑",
        "crescent_moon": "🌙", "rainbow": "🌈",

        // Food & Drink
        "apple": "🍎", "green_apple": "🍏", "tangerine": "🍊", "lemon": "🍋",
        "cherries": "🍒", "grapes": "🍇", "watermelon": "🍉", "strawberry": "🍓",
        "peach": "🍑", "melon": "🍈", "banana": "🍌", "pear": "🍐",
        "pineapple": "🍍", "pizza": "🍕", "hamburger": "🍔", "fries": "🍟",
        "hotdog": "🌭", "taco": "🌮", "burrito": "🌯",
        "egg": "🥚", "coffee": "☕", "tea": "🍵", "beer": "🍺",
        "beers": "🍻", "wine_glass": "🍷", "cocktail": "🍸", "tropical_drink": "🍹",
        "champagne": "🍾", "cake": "🍰", "birthday": "🎂", "cookie": "🍪",
        "chocolate_bar": "🍫", "candy": "🍬", "lollipop": "🍭", "ice_cream": "🍨",
        "doughnut": "🍩",

        // Activity & Sports
        "soccer": "⚽", "basketball": "🏀", "football": "🏈", "baseball": "⚾",
        "tennis": "🎾", "golf": "⛳", "trophy": "🏆", "medal": "🏅",
        "checkered_flag": "🏁", "guitar": "🎸", "microphone": "🎤",
        "headphones": "🎧", "art": "🎨", "video_game": "🎮", "dart": "🎯",
        "game_die": "🎲", "slot_machine": "🎰", "bowling": "🎳",

        // Travel & Places
        "car": "🚗", "taxi": "🚕", "bus": "🚌", "ambulance": "🚑",
        "fire_engine": "🚒", "police_car": "🚓", "truck": "🚚",
        "bike": "🚲", "airplane": "✈️", "rocket": "🚀", "ship": "🚢",
        "boat": "⛵", "sailboat": "⛵", "anchor": "⚓",
        "house": "🏠", "office": "🏢", "hospital": "🏥", "school": "🏫",
        "church": "⛪", "tent": "⛺", "construction": "🚧",

        // Objects
        "watch": "⌚", "iphone": "📱", "computer": "💻", "keyboard": "⌨️",
        "desktop_computer": "🖥️", "printer": "🖨️", "telephone": "☎️",
        "tv": "📺", "camera": "📷", "flashlight": "🔦",
        "bulb": "💡", "battery": "🔋", "electric_plug": "🔌",
        "mag": "🔍", "mag_right": "🔎", "lock": "🔒", "unlock": "🔓",
        "key": "🔑", "bell": "🔔", "no_bell": "🔕", "bookmark": "🔖",
        "link": "🔗", "radio_button": "🔘",
        "paperclip": "📎", "scissors": "✂️", "pencil2": "✏️",
        "pen": "🖊️", "email": "📧", "envelope": "✉️",
        "inbox_tray": "📥", "outbox_tray": "📤", "package": "📦",
        "memo": "📝", "page_facing_up": "📄", "page_with_curl": "📃",
        "book": "📖", "books": "📚", "calendar": "📅",
        "chart_with_upwards_trend": "📈", "chart_with_downwards_trend": "📉",
        "bar_chart": "📊", "clipboard": "📋",
        "pushpin": "📌", "round_pushpin": "📍",
        "wrench": "🔧", "hammer": "🔨", "nut_and_bolt": "🔩",
        "gear": "⚙️", "shield": "🛡️", "gun": "🔫",
        "bomb": "💣", "hourglass": "⌛", "alarm_clock": "⏰",
        "stopwatch": "⏱️", "timer_clock": "⏲️",
        "moneybag": "💰", "money_with_wings": "💸",
        "credit_card": "💳", "gem": "💎",
        "medal_sports": "🏅", "medal_military": "🎖️",
        "pirate_flag": "🏴‍☠️",

        // Symbols
        "100": "💯", "heavy_check_mark": "✔️", "white_check_mark": "✅",
        "ballot_box_with_check": "☑️", "heavy_multiplication_x": "✖️",
        "x": "❌", "negative_squared_cross_mark": "❎",
        "heavy_plus_sign": "➕", "heavy_minus_sign": "➖", "heavy_division_sign": "➗",
        "curly_loop": "➰", "loop": "➿",
        "warning": "⚠️", "no_entry": "⛔", "no_entry_sign": "🚫",
        "sos": "🆘", "information_source": "ℹ️",
        "arrow_right": "➡️", "arrow_left": "⬅️", "arrow_up": "⬆️", "arrow_down": "⬇️",
        "arrow_upper_right": "↗️", "arrow_lower_right": "↘️",
        "arrow_upper_left": "↖️", "arrow_lower_left": "↙️",
        "arrows_counterclockwise": "🔄", "rewind": "⏪", "fast_forward": "⏩",
        "arrow_forward": "▶️", "arrow_backward": "◀️",
        "red_circle": "🔴", "blue_circle": "🔵", "white_circle": "⚪", "black_circle": "⚫",
        "large_blue_circle": "🔵",
        "recycle": "♻️", "peace_symbol": "☮️",
        "copyright": "©️", "registered": "®️", "tm": "™️",
        "hash": "#️⃣", "asterisk": "*️⃣",
        "zero": "0️⃣", "one": "1️⃣", "two": "2️⃣", "three": "3️⃣",
        "four": "4️⃣", "five": "5️⃣", "six": "6️⃣", "seven": "7️⃣",
        "eight": "8️⃣", "nine": "9️⃣", "keycap_ten": "🔟",

        // Flags (common)
        "de": "🇩🇪", "flag_de": "🇩🇪",
        "eu": "🇪🇺", "flag_eu": "🇪🇺",
        "at": "🇦🇹", "flag_at": "🇦🇹",
        "ch": "🇨🇭", "flag_ch": "🇨🇭",
        "us": "🇺🇸", "flag_us": "🇺🇸",
        "gb": "🇬🇧", "flag_gb": "🇬🇧", "uk": "🇬🇧",
        "fr": "🇫🇷", "flag_fr": "🇫🇷",
    ]
}
