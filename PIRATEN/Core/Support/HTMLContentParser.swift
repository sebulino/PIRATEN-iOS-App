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

    /// Extracts image URLs from HTML `<img>` tags, excluding emoji and avatar images.
    /// - Parameter html: The HTML string to extract images from
    /// - Returns: Array of image URLs found in the HTML
    static func extractImageURLs(from html: String) -> [URL] {
        // Match <img> tags that are NOT emoji and NOT avatar
        let pattern = #"<img\s+(?![^>]*class\s*=\s*"[^"]*(emoji|avatar))[^>]*src\s*=\s*"([^"]+)"[^>]*/?\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        return matches.compactMap { match in
            // Capture group 2 is the src URL (group 1 is the emoji|avatar alternation)
            guard let srcRange = Range(match.range(at: 2), in: html) else { return nil }
            let src = String(html[srcRange])
            if src.contains("emoji") || src.contains("/user_avatar/") { return nil }
            return URL(string: src)
        }
    }

    /// Replaces Discourse emoji `<img>` tags and `:shortcode:` text with Unicode emojis.
    static func replaceEmojiShortcodes(in text: String) -> String {
        var result = text

        // Replace Discourse <img class="emoji..." title=":name:" ...> tags with :name:
        result = result.replacingOccurrences(
            of: #"<img[^>]*class="[^"]*emoji[^"]*"[^>]*title=":([^"]+):"[^>]*/?\s*>"#,
            with: ":$1:",
            options: .regularExpression
        )
        // Also handle reversed attribute order (title before class)
        result = result.replacingOccurrences(
            of: #"<img[^>]*title=":([^"]+):"[^>]*class="[^"]*emoji[^"]*"[^>]*/?\s*>"#,
            with: ":$1:",
            options: .regularExpression
        )

        // Fallback: catch any remaining emoji <img> tags using the alt attribute.
        // Some Discourse versions/plugins omit the title attribute or use a different format.
        result = result.replacingOccurrences(
            of: #"<img[^>]*class="[^"]*emoji[^"]*"[^>]*alt=":([^"]+):"[^>]*/?\s*>"#,
            with: ":$1:",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"<img[^>]*alt=":([^"]+):"[^>]*class="[^"]*emoji[^"]*"[^>]*/?\s*>"#,
            with: ":$1:",
            options: .regularExpression
        )

        // Last resort: remove any remaining <img> tags with class="emoji" that weren't
        // matched above (e.g. custom emojis without title/alt shortcodes).
        // Replace with empty string to avoid broken images from relative Discourse URLs.
        result = result.replacingOccurrences(
            of: #"<img[^>]*class="[^"]*emoji[^"]*"[^>]*/?\s*>"#,
            with: "",
            options: .regularExpression
        )

        // Strip skin tone suffixes BEFORE the emojiMap pass, otherwise
        // :wave: inside :wave:t2: gets greedily matched and leaves "👋t2:" behind.
        result = result.replacingOccurrences(
            of: #":([a-z_0-9+\-]+):t[2-6]:"#,
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
        "slight_smile": "🙂", "slightly_smiling_face": "🙂", "slightly_frowning_face": "🙁",
        "upside_down_face": "🙃", "rolling_eyes": "🙄", "thinking": "🤔",
        "zipper_mouth_face": "🤐", "face_with_thermometer": "🤒",
        "face_with_head_bandage": "🤕", "money_mouth_face": "🤑",
        "hugs": "🤗", "crossed_fingers": "🤞", "handshake": "🤝",
        "rofl": "🤣", "face_palm": "🤦", "shrug": "🤷",
        "face_with_monocle": "🧐", "partying_face": "🥳",
        "pleading_face": "🥺", "yawning_face": "🥱",
        "speaking_head": "🗣️", "speech_balloon": "💬", "thought_balloon": "💭",
        "left_speech_bubble": "🗨️", "right_anger_bubble": "🗯️",
        "raised_eyebrow": "🤨", "star_struck": "🤩", "zany_face": "🤪",
        "face_with_symbols_on_mouth": "🤬", "exploding_head": "🤯",
        "cursing_face": "🤬", "vomiting_face": "🤮", "shushing_face": "🤫",
        "lying_face": "🤥", "face_with_hand_over_mouth": "🤭",
        "cowboy_hat_face": "🤠", "clown_face": "🤡", "nauseated_face": "🤢",
        "sneezing_face": "🤧", "woozy_face": "🥴", "hot_face": "🥵",
        "cold_face": "🥶", "disguised_face": "🥸", "smiling_face_with_tear": "🥲",
        "pinched_fingers": "🤌", "palms_up_together": "🤲",
        "leg": "🦵", "foot": "🦶", "ear_with_hearing_aid": "🦻",
        "brain": "🧠", "tooth": "🦷", "bone": "🦴", "lungs": "🫁",
        "heart_on_fire": "❤️‍🔥", "mending_heart": "❤️‍🩹",
        "anatomical_heart": "🫀", "people_hugging": "🫂",
        "man_beard": "🧔", "woman_beard": "🧔‍♀️",
        "superhero": "🦸", "supervillain": "🦹",
        "mage": "🧙", "fairy": "🧚", "vampire": "🧛",
        "merperson": "🧜", "elf": "🧝", "genie": "🧞", "zombie": "🧟",
        "person_in_lotus_position": "🧘", "person_climbing": "🧗",
        "person_in_steamy_room": "🧖",
        "palms_up": "🤲", "selfie": "🤳", "pregnant_woman": "🤰",
        "man_dancing": "🕺", "levitate": "🕴️",
        "person_doing_cartwheel": "🤸", "person_juggling": "🤹",
        "person_in_tuxedo": "🤵", "bride_with_veil": "👰",
        "mrs_claus": "🤶", "santa": "🎅",

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
        "bee": "🐝", "honeybee": "🐝", "ant": "🐜", "beetle": "🪲",
        "butterfly": "🦋", "ladybug": "🐞", "cricket": "🦗",
        "scorpion": "🦂", "mosquito": "🦟", "fly": "🪰", "worm": "🪱",
        "spider": "🕷️", "spider_web": "🕸️",
        "crocodile": "🐊", "leopard": "🐆", "zebra": "🦓", "gorilla": "🦍",
        "orangutan": "🦧", "deer": "🦌", "bison": "🦬",
        "cow2": "🐄", "ox": "🐂", "water_buffalo": "🐃",
        "pig2": "🐖", "ram": "🐏", "llama": "🦙", "giraffe": "🦒",
        "hippopotamus": "🦛", "rhinoceros": "🦏", "dromedary_camel": "🐪",
        "mouse2": "🐁", "rat": "🐀", "rabbit2": "🐇", "chipmunk": "🐿️",
        "hedgehog": "🦔", "bat": "🦇",
        "polar_bear": "🐻‍❄️", "panda_face": "🐼", "sloth": "🦥",
        "otter": "🦦", "skunk": "🦨", "kangaroo": "🦘", "badger": "🦡",
        "turkey": "🦃", "chicken": "🐔", "rooster": "🐓",
        "hatching_chick": "🐣", "baby_chick": "🐤", "hatched_chick": "🐥",
        "eagle": "🦅", "duck": "🦆", "swan": "🦢", "owl": "🦉",
        "dodo": "🦤", "feather": "🪶", "flamingo": "🦩", "peacock": "🦚",
        "parrot": "🦜", "tropical_fish": "🐠", "blowfish": "🐡",
        "shark": "🦈", "whale2": "🐋", "seal": "🦭",
        "dog2": "🐕", "guide_dog": "🦮", "service_dog": "🐕‍🦺",
        "poodle": "🐩", "cat2": "🐈", "black_cat": "🐈‍⬛",
        "lion": "🦁", "tiger2": "🐅", "horse_racing": "🏇",
        "unicorn": "🦄", "mammoth": "🦣",
        "dragon": "🐉", "dragon_face": "🐲", "sauropod": "🦕", "t_rex": "🦖",
        "herb": "🌿", "shamrock": "☘️", "hibiscus": "🌺",
        "wilted_flower": "🥀", "blossom": "🌼", "ear_of_rice": "🌾",
        "plant": "🌿", "leaves": "🍃",

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
        "avocado": "🥑", "eggplant": "🍆", "potato": "🥔", "carrot": "🥕",
        "corn": "🌽", "hot_pepper": "🌶️", "cucumber": "🥒", "broccoli": "🥦",
        "garlic": "🧄", "onion": "🧅", "peanuts": "🥜",
        "bread": "🍞", "croissant": "🥐", "baguette_bread": "🥖",
        "pretzel": "🥨", "bagel": "🥯", "pancakes": "🥞", "waffle": "🧇",
        "cheese": "🧀", "meat_on_bone": "🍖", "poultry_leg": "🍗",
        "bacon": "🥓", "cut_of_meat": "🥩", "stew": "🍲",
        "green_salad": "🥗", "popcorn": "🍿", "butter": "🧈",
        "salt": "🧂", "canned_food": "🥫", "bento": "🍱",
        "rice_cracker": "🍘", "rice_ball": "🍙", "rice": "🍚",
        "curry": "🍛", "ramen": "🍜", "spaghetti": "🍝",
        "sweet_potato": "🍠", "oden": "🍢", "sushi": "🍣",
        "fried_shrimp": "🍤", "fish_cake": "🍥", "moon_cake": "🥮",
        "dumpling": "🥟", "fortune_cookie": "🥠", "takeout_box": "🥡",
        "pie": "🥧", "cupcake": "🧁", "custard": "🍮",
        "honey_pot": "🍯", "baby_bottle": "🍼",
        "milk_glass": "🥛", "hot_beverage": "☕",
        "tumbler_glass": "🥃", "cup_with_straw": "🥤",
        "bubble_tea": "🧋", "beverage_box": "🧃",
        "mate": "🧉", "ice_cube": "🧊",
        "chopsticks": "🥢", "plate_with_cutlery": "🍽️",
        "fork_and_knife": "🍴", "spoon": "🥄",

        // Activity & Sports
        "soccer": "⚽", "basketball": "🏀", "football": "🏈", "baseball": "⚾",
        "tennis": "🎾", "golf": "⛳", "trophy": "🏆", "medal": "🏅",
        "checkered_flag": "🏁", "guitar": "🎸", "microphone": "🎤",
        "headphones": "🎧", "art": "🎨", "video_game": "🎮", "dart": "🎯",
        "game_die": "🎲", "slot_machine": "🎰", "bowling": "🎳",
        "cricket_game": "🏏", "field_hockey": "🏑", "ice_hockey": "🏒",
        "lacrosse": "🥍", "ping_pong": "🏓", "badminton": "🏸",
        "boxing_glove": "🥊", "martial_arts_uniform": "🥋",
        "goal_net": "🥅", "flying_disc": "🥏", "boomerang": "🪃",
        "ice_skate": "⛸️", "fishing_pole_and_fish": "🎣",
        "diving_mask": "🤿", "running_shirt_with_sash": "🎽",
        "ski": "🎿", "sled": "🛷", "curling_stone": "🥌",
        "yo_yo": "🪀", "kite": "🪁", "pool_8_ball": "🎱",
        "crystal_ball": "🔮", "magic_wand": "🪄",
        "jigsaw": "🧩", "teddy_bear": "🧸", "pinata": "🪅",
        "nesting_dolls": "🪆",
        "performing_arts": "🎭", "frame_with_picture": "🖼️",
        "paintbrush": "🖌️", "crayon": "🖍️",
        "drum": "🥁", "long_drum": "🪘", "accordion": "🪗",
        "banjo": "🪕", "saxophone": "🎷", "trumpet": "🎺",
        "violin": "🎻", "musical_keyboard": "🎹",
        "movie_camera": "🎥", "film_strip": "🎞️", "projector": "📽️",
        "clapper": "🎬", "television": "📺",
        "ticket": "🎫", "admission_tickets": "🎟️",
        "ribbon": "🎀", "gift": "🎁", "reminder_ribbon": "🎗️",
        "confetti_ball": "🎊", "tada": "🎉", "balloon": "🎈",
        "christmas_tree": "🎄", "jack_o_lantern": "🎃",
        "fireworks": "🎆", "sparkler": "🎇",
        "firecracker": "🧨",

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
        "book": "📖", "open_book": "📖", "closed_book": "📕",
        "green_book": "📗", "blue_book": "📘", "orange_book": "📙",
        "notebook": "📓", "notebook_with_decorative_cover": "📔",
        "ledger": "📒", "books": "📚", "calendar": "📅",
        "newspaper": "📰", "rolled_up_newspaper": "🗞️",
        "label": "🏷️", "bookmark_tabs": "📑",
        "scroll": "📜", "receipt": "🧾",
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
        "loudspeaker": "📢", "mega": "📣", "postal_horn": "📯",
        "microphone2": "🎙️", "level_slider": "🎚️", "control_knobs": "🎛️",
        "radio": "📻", "satellite": "📡", "compass": "🧭",
        "map": "🗺️", "world_map": "🗺️",
        "telescope": "🔭", "microscope": "🔬",
        "candle": "🕯️", "light_bulb": "💡",
        "door": "🚪", "bed": "🛏️", "couch_and_lamp": "🛋️",
        "chair": "🪑", "toilet": "🚽", "shower": "🚿", "bathtub": "🛁",
        "broom": "🧹", "basket": "🧺", "soap": "🧼",
        "sponge": "🧽", "fire_extinguisher": "🧯",
        "shopping_cart": "🛒", "luggage": "🧳",
        "toolbox": "🧰", "magnet": "🧲", "test_tube": "🧪",
        "petri_dish": "🧫", "dna": "🧬", "abacus": "🧮",
        "safety_pin": "🧷", "thread": "🧵", "yarn": "🧶",
        "knot": "🪢", "sewing_needle": "🪡",
        "stethoscope": "🩺", "adhesive_bandage": "🩹", "pill": "💊",
        "syringe": "💉", "drop_of_blood": "🩸",
        "ballot_box": "🗳️", "pencil": "📝",
        "file_folder": "📁", "open_file_folder": "📂",
        "card_index_dividers": "🗂️", "date": "📅",
        "calendar_spiral": "🗓️", "card_index": "📇",
        "wastebasket": "🗑️", "file_cabinet": "🗄️",
        "envelope_with_arrow": "📩", "incoming_envelope": "📨",
        "mailbox": "📫", "mailbox_closed": "📪",
        "mailbox_with_mail": "📬", "mailbox_with_no_mail": "📭",
        "postbox": "📮",
        "crossed_swords": "⚔️", "dagger": "🗡️", "bow_and_arrow": "🏹",
        "axe": "🪓", "hammer_and_wrench": "🛠️",
        "chains": "⛓️", "clamp": "🗜️",
        "balance_scale": "⚖️", "probing_cane": "🦯",
        "ladder": "🪜", "mirror": "🪞", "window": "🪟",
        "plunger": "🪠", "mouse_trap": "🪤",
        "bucket": "🪣", "toothbrush": "🪥",
        "headstone": "🪦", "placard": "🪧",
        "rock": "🪨", "wood": "🪵",
        "coin": "🪙",

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

        // Additional symbols
        "bangbang": "‼️", "interrobang": "⁉️",
        "wavy_dash": "〰️", "infinity": "♾️",
        "fleur_de_lis": "⚜️", "trident": "🔱", "name_badge": "📛",
        "beginner": "🔰", "o": "⭕",
        "white_square_button": "🔳", "black_square_button": "🔲",
        "black_small_square": "▪️", "white_small_square": "▫️",
        "black_medium_small_square": "◾", "white_medium_small_square": "◽",
        "black_medium_square": "◼️", "white_medium_square": "◻️",
        "black_large_square": "⬛", "white_large_square": "⬜",
        "orange_circle": "🟠", "yellow_circle": "🟡", "green_circle": "🟢",
        "purple_circle": "🟣", "brown_circle": "🟤",
        "red_square": "🟥", "orange_square": "🟧", "yellow_square": "🟨",
        "green_square": "🟩", "blue_square": "🟦", "purple_square": "🟪",
        "brown_square": "🟫",
        "up": "🆙", "new": "🆕", "free": "🆓", "cool": "🆒",
        "ok": "🆗", "ng": "🆖", "abc": "🔤", "abcd": "🔡",
        "capital_abcd": "🔠", "symbols": "🔣",
        "1234": "🔢", "a": "🅰️", "b": "🅱️", "ab": "🆎", "o2": "🅾️",
        "cl": "🆑", "vs": "🆚", "id": "🆔",
        "parking": "🅿️", "atm": "🏧",
        "accept": "🉑", "congratulations": "㊗️", "secret": "㊙️",
        "radioactive": "☢️", "biohazard": "☣️",
        "atom_symbol": "⚛️", "wheel_of_dharma": "☸️",
        "yin_yang": "☯️", "cross": "✝️", "orthodox_cross": "☦️",
        "star_and_crescent": "☪️", "star_of_david": "✡️",
        "menorah": "🕎", "om": "🕉️",
        "female_sign": "♀️", "male_sign": "♂️",
        "transgender_symbol": "⚧️",
        "heart_decoration": "💟", "anger_symbol": "💢",
        "diamond_shape_with_a_dot_inside": "💠",
        "globe_with_meridians": "🌐",
        "m": "Ⓜ️",
        "chart": "💹",
        "part_alternation_mark": "〽️",
        "japanese_castle": "🏯", "european_castle": "🏰",
        "stadium": "🏟️", "statue_of_liberty": "🗽",
        "railway_car": "🚃", "bullettrain_side": "🚄", "bullettrain_front": "🚅",
        "train": "🚋", "metro": "🚇", "light_rail": "🚈", "station": "🚉",
        "tram": "🚊", "monorail": "🚝", "mountain_railway": "🚞",
        "minibus": "🚐", "trolleybus": "🚎",
        "racing_car": "🏎️", "motorcycle": "🏍️",
        "motor_scooter": "🛵", "manual_wheelchair": "🦽",
        "motorized_wheelchair": "🦼", "auto_rickshaw": "🛺",
        "kick_scooter": "🛴", "skateboard": "🛹", "roller_skate": "🛼",
        "helicopter": "🚁", "small_airplane": "🛩️",
        "flying_saucer": "🛸", "parachute": "🪂",
        "seat": "💺", "canoe": "🛶", "speedboat": "🚤",
        "passenger_ship": "🛳️", "ferry": "⛴️", "motor_boat": "🛥️",
        "fuelpump": "⛽", "vertical_traffic_light": "🚦",
        "traffic_light": "🚥", "busstop": "🚏",
        "moyai": "🗿",

        // Flags (common)
        "de": "🇩🇪", "flag_de": "🇩🇪",
        "eu": "🇪🇺", "flag_eu": "🇪🇺",
        "at": "🇦🇹", "flag_at": "🇦🇹",
        "ch": "🇨🇭", "flag_ch": "🇨🇭",
        "us": "🇺🇸", "flag_us": "🇺🇸",
        "gb": "🇬🇧", "flag_gb": "🇬🇧", "uk": "🇬🇧",
        "fr": "🇫🇷", "flag_fr": "🇫🇷",

        // -------------------------------------------------------
        // Unicode CLDR / alternative names used by newer Discourse
        // -------------------------------------------------------

        // Smileys — CLDR names
        "grinning_face": "😀", "grinning_face_with_big_eyes": "😃",
        "grinning_face_with_smiling_eyes": "😄",
        "beaming_face_with_smiling_eyes": "😁",
        "grinning_squinting_face": "😆",
        "grinning_face_with_sweat": "😅",
        "rolling_on_the_floor_laughing": "🤣",
        "face_with_tears_of_joy": "😂",
        "slightly_smiling": "🙂",
        "smiling_face": "😊", "smiling_face_with_smiling_eyes": "😊",
        "smiling_face_with_halo": "😇",
        "smiling_face_with_hearts": "🥰",
        "smiling_face_with_heart_eyes": "😍",
        "face_blowing_a_kiss": "😘",
        "kissing_face": "😗",
        "kissing_face_with_smiling_eyes": "😙",
        "kissing_face_with_closed_eyes": "😚",
        "face_savoring_food": "😋",
        "face_with_tongue": "😛",
        "winking_face_with_tongue": "😜",
        "squinting_face_with_tongue": "😝",
        "zany": "🤪",
        "money_mouth": "🤑",
        "smiling_face_with_open_hands": "🤗",
        "face_with_open_eyes_and_hand_over_mouth": "🤭",
        "shushing": "🤫",
        "thinking_face": "🤔",
        "zipper_mouth": "🤐",
        "face_with_raised_eyebrow": "🤨",
        "neutral": "😐",
        "expressionless_face": "😑",
        "face_without_mouth": "😶",
        "dotted_line_face": "🫥",
        "face_in_clouds": "😶‍🌫️",
        "smirking_face": "😏",
        "unamused_face": "😒",
        "face_with_rolling_eyes": "🙄",
        "grimacing_face": "😬",
        "face_exhaling": "😮‍💨",
        "lying": "🤥",
        "relieved_face": "😌",
        "pensive_face": "😔",
        "sleepy_face": "😪",
        "drooling_face": "🤤",
        "sleeping_face": "😴",
        "face_with_medical_mask": "😷",
        "face_with_thermometer_cldr": "🤒",
        "face_with_head_bandage_cldr": "🤕",
        "nauseated": "🤢",
        "face_vomiting": "🤮",
        "sneezing": "🤧",
        "hot": "🥵",
        "cold": "🥶",
        "woozy": "🥴",
        "face_with_crossed_out_eyes": "😵",
        "face_with_spiral_eyes": "😵‍💫",
        "exploding": "🤯",
        "cowboy": "🤠",
        "partying": "🥳",
        "disguised": "🥸",
        "smiling_face_with_sunglasses": "😎",
        "nerd": "🤓",
        "face_with_monocle_cldr": "🧐",
        "confused_face": "😕",
        "face_with_diagonal_mouth": "🫤",
        "worried_face": "😟",
        "slightly_frowning": "🙁",
        "frowning_face": "☹️",
        "frowning_face_with_open_mouth": "😦",
        "anguished_face": "😧",
        "astonished_face": "😲",
        "flushed_face": "😳",
        "pleading": "🥺",
        "face_holding_back_tears": "🥹",
        "fearful_face": "😨",
        "anxious_face_with_sweat": "😰",
        "sad_but_relieved_face": "😥",
        "crying_face": "😢",
        "loudly_crying_face": "😭",
        "face_screaming_in_fear": "😱",
        "confounded_face": "😖",
        "persevering_face": "😣",
        "disappointed_face": "😞",
        "downcast_face_with_sweat": "😓",
        "weary_face": "😩",
        "tired": "😫",
        "yawning": "🥱",
        "face_with_steam_from_nose": "😤",
        "enraged_face": "😡",
        "angry_face": "😠",
        "face_with_symbols_over_mouth": "🤬",
        "smiling_face_with_horns": "😈",
        "angry_face_with_horns": "👿",
        "skull_emoji": "💀", "skull_and_crossbones": "☠️",
        "pile_of_poo": "💩",
        "clown": "🤡",
        "ogre": "👹", "goblin": "👺",
        "ghost_cldr": "👻",
        "alien_cldr": "👽", "alien_monster": "👾",
        "robot_face": "🤖",
        "cat_face": "🐱", "grinning_cat": "😺",
        "grinning_cat_with_smiling_eyes": "😸",
        "cat_with_tears_of_joy": "😹",
        "smiling_cat_with_heart_eyes": "😻",
        "cat_with_wry_smile": "😼",
        "kissing_cat": "😽", "weary_cat": "🙀",
        "crying_cat": "😿", "pouting_cat": "😾",
        "see_no_evil": "🙈", "hear_no_evil": "🙉", "speak_no_evil": "🙊",

        // Hands — CLDR names
        "waving_hand": "👋",
        "raised_back_of_hand": "🤚",
        "hand_with_fingers_splayed": "🖐️",
        "raised_hand_cldr": "✋",
        "vulcan_salute": "🖖",
        "rightwards_hand": "🫱", "leftwards_hand": "🫲",
        "palm_down_hand": "🫳", "palm_up_hand": "🫴",
        "rightwards_pushing_hand": "🫸", "leftwards_pushing_hand": "🫷",
        "ok_hand_cldr": "👌",
        "pinched_fingers_cldr": "🤌",
        "pinching_hand": "🤏",
        "victory_hand": "✌️",
        "crossed_fingers_cldr": "🤞",
        "hand_with_index_finger_and_thumb_crossed": "🫰",
        "love_you_gesture": "🤟",
        "sign_of_the_horns": "🤘",
        "call_me_hand": "🤙",
        "backhand_index_pointing_left": "👈",
        "backhand_index_pointing_right": "👉",
        "backhand_index_pointing_up": "👆",
        "middle_finger": "🖕",
        "backhand_index_pointing_down": "👇",
        "index_pointing_up": "☝️",
        "index_pointing_at_the_viewer": "🫵",
        "thumbs_up": "👍", "thumbs_down": "👎",
        "raised_fist": "✊",
        "oncoming_fist": "👊",
        "left_facing_fist": "🤛", "right_facing_fist": "🤜",
        "clapping_hands": "👏",
        "raising_hands": "🙌",
        "heart_hands": "🫶",
        "open_hands_cldr": "👐",
        "palms_up_together_cldr": "🤲",
        "handshake_cldr": "🤝",
        "folded_hands": "🙏",
        "writing_hand": "✍️",
        "nail_polish": "💅",
        "selfie_cldr": "🤳",
        "flexed_biceps": "💪",
        "mechanical_arm": "🦾", "mechanical_leg": "🦿",

        // People — CLDR names
        "person_standing": "🧍", "person_kneeling": "🧎",
        "person_walking": "🚶", "person_running": "🏃",
        "woman_dancing": "💃", "man_dancing_cldr": "🕺",
        "person_in_suit_levitating": "🕴️",
        "person_bowing": "🙇",
        "person_gesturing_no": "🙅",
        "person_gesturing_ok": "🙆",
        "person_tipping_hand": "💁",
        "person_raising_hand": "🙋",
        "deaf_person": "🧏",
        "person_facepalming": "🤦",
        "person_shrugging": "🤷",
        "person_pouting": "🙎",
        "person_frowning_cldr": "🙍",
        "person_getting_haircut": "💇",
        "person_getting_massage": "💆",
        "person_in_steamy_room_cldr": "🧖",
        "person_climbing_cldr": "🧗",
        "person_fencing": "🤺",
        "person_cartwheeling": "🤸",
        "people_wrestling": "🤼",
        "person_playing_water_polo": "🤽",
        "person_playing_handball": "🤾",
        "person_juggling_cldr": "🤹",
        "person_in_lotus_position_cldr": "🧘",
        "baby_cldr": "👶", "child": "🧒",
        "boy_cldr": "👦", "girl_cldr": "👧",
        "person_blond_hair": "👱",
        "man_cldr": "👨", "woman_cldr": "👩",
        "older_person": "🧓",
        "old_man": "👴", "old_woman": "👵",
        "person_with_crown": "🫅",
        "prince": "🤴", "princess_cldr": "👸",
        "person_wearing_turban": "👳",
        "person_with_skullcap": "👲",
        "woman_with_headscarf": "🧕",
        "pregnant_person": "🫃", "pregnant_man": "🫄",
        "breast_feeding": "🤱",
        "baby_angel": "👼",
        "santa_claus": "🎅", "mrs_claus_cldr": "🤶",
        "person_in_tuxedo_cldr": "🤵",
        "person_with_veil": "👰",
        "superhero_cldr": "🦸", "supervillain_cldr": "🦹",
        "mage_cldr": "🧙", "fairy_cldr": "🧚",
        "vampire_cldr": "🧛", "merperson_cldr": "🧜",
        "elf_cldr": "🧝", "genie_cldr": "🧞", "zombie_cldr": "🧟",
        "troll": "🧌",
        "person_beard": "🧔",
        "detective": "🕵️", "guard": "💂",
        "ninja": "🥷", "construction_worker": "👷",
        "person_with_crown_cldr": "🫅",
        "police_officer": "👮",
        "bust_in_silhouette": "👤", "busts_in_silhouette": "👥",
        "people_holding_hands": "🧑‍🤝‍🧑",
        "couple_with_heart_cldr": "💑", "kiss_mark": "💋",
        "family_cldr": "👪",
        "speaking_head_cldr": "🗣️",

        // Body parts — CLDR names
        "eyes_cldr": "👀",
        "eye_cldr": "👁️",
        "ear": "👂",
        "nose": "👃",
        "brain_cldr": "🧠",
        "anatomical_heart_cldr": "🫀",
        "lungs_cldr": "🫁",
        "tooth_cldr": "🦷",
        "bone_cldr": "🦴",
        "tongue_cldr": "👅",
        "mouth": "👄",
        "biting_lip": "🫦",
        "footprints": "👣",

        // Hearts — CLDR names
        "red_heart": "❤️",
        "orange_heart": "🧡",
        "yellow_heart_cldr": "💛",
        "green_heart_cldr": "💚",
        "blue_heart_cldr": "💙",
        "purple_heart_cldr": "💜",
        "black_heart": "🖤",
        "white_heart": "🤍",
        "brown_heart": "🤎",
        "pink_heart": "🩷",
        "light_blue_heart": "🩵",
        "grey_heart": "🩶",
        "heart_with_arrow": "💘",
        "heart_with_ribbon": "💝",
        "sparkling_heart_cldr": "💖",
        "growing_heart": "💗",
        "beating_heart": "💓",
        "revolving_hearts_cldr": "💞",
        "two_hearts_cldr": "💕",
        "heart_exclamation": "❣️",
        "broken_heart_cldr": "💔",
        "heart_on_fire_cldr": "❤️‍🔥",
        "mending_heart_cldr": "❤️‍🩹",

        // Nature — CLDR names
        "dog_face": "🐶", "cat_face_cldr": "🐱",
        "mouse_face": "🐭", "hamster_face": "🐹",
        "rabbit_face": "🐰", "fox_face": "🦊", "fox": "🦊",
        "bear_face": "🐻",
        "panda": "🐼",
        "polar_bear_face": "🐻‍❄️",
        "koala_cldr": "🐨",
        "tiger_face": "🐯",
        "lion_face": "🦁",
        "cow_face": "🐮",
        "pig_face": "🐷", "pig_nose": "🐽",
        "frog_face": "🐸",
        "monkey_face_cldr": "🐵",
        "see_no_evil_monkey": "🙈",
        "hear_no_evil_monkey": "🙉",
        "speak_no_evil_monkey": "🙊",
        "horse_face": "🐴",
        "unicorn_face": "🦄",
        "dog_cldr": "🐕", "cat_cldr": "🐈",
        "wolf_face": "🐺",
        "chicken_cldr": "🐔", "rooster_cldr": "🐓",
        "hatching_chick_cldr": "🐣",
        "baby_chick_cldr": "🐤", "front_facing_baby_chick": "🐥",
        "bird_cldr": "🐦",
        "penguin_cldr": "🐧",
        "eagle_cldr": "🦅",
        "duck_cldr": "🦆",
        "swan_cldr": "🦢", "owl_cldr": "🦉",
        "flamingo_cldr": "🦩", "peacock_cldr": "🦚", "parrot_cldr": "🦜",
        "snake_cldr": "🐍",
        "dragon_cldr": "🐉", "dragon_face_cldr": "🐲",
        "turtle_cldr": "🐢",
        "lizard": "🦎",
        "crocodile_cldr": "🐊",
        "whale_cldr": "🐳", "spouting_whale": "🐳",
        "dolphin_cldr": "🐬",
        "fish_cldr": "🐟",
        "tropical_fish_cldr": "🐠",
        "blowfish_cldr": "🐡",
        "shark_cldr": "🦈",
        "octopus_cldr": "🐙",
        "snail_cldr": "🐌",
        "butterfly_cldr": "🦋",
        "bug_cldr": "🐛",
        "ant_cldr": "🐜",
        "honeybee_cldr": "🐝",
        "lady_beetle": "🐞",
        "spider_cldr": "🕷️",
        "scorpion_cldr": "🦂",
        "mosquito_cldr": "🦟",
        "cockroach": "🪳",
        "sunflower_cldr": "🌻",
        "rose_cldr": "🌹",
        "cherry_blossom_cldr": "🌸",
        "tulip_cldr": "🌷",
        "hibiscus_cldr": "🌺",
        "bouquet_cldr": "💐",
        "wilted_flower_cldr": "🥀",
        "seedling_cldr": "🌱",
        "evergreen_tree_cldr": "🌲",
        "deciduous_tree_cldr": "🌳",
        "palm_tree_cldr": "🌴",
        "cactus_cldr": "🌵",
        "mushroom_cldr": "🍄",
        "fallen_leaf_cldr": "🍂",
        "maple_leaf_cldr": "🍁",
        "four_leaf_clover_cldr": "🍀",
        "rainbow_cldr": "🌈",
        "sun": "☀️", "sun_with_face": "🌞",
        "full_moon_face": "🌝", "new_moon_face": "🌚",
        "cloud_cldr": "☁️",
        "cloud_with_rain": "🌧️",
        "cloud_with_lightning_and_rain": "⛈️",
        "cloud_with_lightning": "🌩️",
        "cloud_with_snow": "🌨️",
        "tornado_cldr": "🌪️",
        "water_wave": "🌊",

        // Food — CLDR names
        "red_apple": "🍎", "green_apple_cldr": "🍏",
        "grapes_cldr": "🍇",
        "watermelon_cldr": "🍉",
        "tangerine_cldr": "🍊", "mandarin": "🍊", "orange": "🍊",
        "lemon_cldr": "🍋",
        "banana_cldr": "🍌",
        "pineapple_cldr": "🍍",
        "mango": "🥭",
        "strawberry_cldr": "🍓", "blueberries": "🫐",
        "cherries_cldr": "🍒",
        "peach_cldr": "🍑",
        "kiwi_fruit": "🥝", "kiwi": "🥝",
        "coconut": "🥥",
        "tomato": "🍅",
        "eggplant_cldr": "🍆",
        "avocado_cldr": "🥑",
        "hot_pepper_cldr": "🌶️",
        "pizza_cldr": "🍕",
        "hamburger_cldr": "🍔",
        "french_fries": "🍟",
        "hot_dog": "🌭",
        "taco_cldr": "🌮",
        "burrito_cldr": "🌯",
        "sandwich": "🥪",
        "stuffed_flatbread": "🥙",
        "falafel": "🧆",
        "cooking": "🍳",
        "spaghetti_cldr": "🍝",
        "steaming_bowl": "🍜",
        "curry_rice": "🍛",
        "sushi_cldr": "🍣",
        "bento_box": "🍱",
        "ice_cream_cldr": "🍨", "shaved_ice": "🍧", "soft_ice_cream": "🍦",
        "shortcake": "🍰", "birthday_cake": "🎂",
        "cookie_cldr": "🍪",
        "doughnut_cldr": "🍩",
        "chocolate_bar_cldr": "🍫",
        "candy_cldr": "🍬",
        "lollipop_cldr": "🍭",
        "wine_glass_cldr": "🍷",
        "beer_mug": "🍺",
        "clinking_beer_mugs": "🍻",
        "clinking_glasses": "🥂",
        "cocktail_glass": "🍸",
        "tropical_drink_cldr": "🍹",
        "bottle_with_popping_cork": "🍾",
        "teacup_without_handle": "🍵",
        "hot_beverage_cldr": "☕",

        // Activity — CLDR names
        "soccer_ball": "⚽",
        "basketball_cldr": "🏀",
        "american_football": "🏈",
        "baseball_cldr": "⚾",
        "tennis_cldr": "🎾",
        "volleyball": "🏐",
        "rugby_football": "🏉",
        "trophy_cldr": "🏆",
        "guitar_cldr": "🎸",
        "microphone_cldr": "🎤",
        "headphone": "🎧",
        "artist_palette": "🎨",
        "video_game_cldr": "🎮",
        "game_die_cldr": "🎲",
        "direct_hit": "🎯",
        "party_popper": "🎉",
        "confetti_ball_cldr": "🎊",
        "balloon_cldr": "🎈",
        "christmas_tree_cldr": "🎄",
        "jack_o_lantern_cldr": "🎃",
        "wrapped_gift": "🎁",
        "fireworks_cldr": "🎆",

        // Travel — CLDR names
        "automobile": "🚗",
        "oncoming_automobile": "🚘",
        "sport_utility_vehicle": "🚙",
        "bus_cldr": "🚌",
        "trolleybus_cldr": "🚎",
        "ambulance_cldr": "🚑",
        "fire_engine_cldr": "🚒",
        "police_car_cldr": "🚓",
        "taxi_cldr": "🚕",
        "oncoming_taxi": "🚖",
        "delivery_truck": "🚚",
        "bicycle": "🚲",
        "airplane_cldr": "✈️",
        "rocket_cldr": "🚀",
        "ship_cldr": "🚢",
        "sailboat_cldr": "⛵",
        "house_cldr": "🏠", "house_with_garden": "🏡",
        "office_building": "🏢",
        "school_cldr": "🏫",
        "hospital_cldr": "🏥",

        // Objects — CLDR names
        "laptop": "💻", "mobile_phone": "📱",
        "desktop_computer_cldr": "🖥️",
        "keyboard_cldr": "⌨️",
        "magnifying_glass_tilted_left": "🔍",
        "magnifying_glass_tilted_right": "🔎",
        "locked": "🔒", "unlocked": "🔓",
        "key_cldr": "🔑", "old_key": "🗝️",
        "light_bulb_cldr": "💡",
        "electric_plug_cldr": "🔌",
        "battery_cldr": "🔋",
        "bell_cldr": "🔔", "bell_with_slash": "🔕",
        "link_cldr": "🔗",
        "scissors_cldr": "✂️",
        "money_bag": "💰",
        "dollar_banknote": "💵", "euro_banknote": "💶",
        "credit_card_cldr": "💳",
        "gem_stone": "💎",
        "open_mailbox_with_raised_flag": "📬",
        "open_mailbox_with_lowered_flag": "📭",
        "closed_mailbox_with_raised_flag": "📫",
        "closed_mailbox_with_lowered_flag": "📪",
        "package_cldr": "📦",
        "tear_off_calendar": "📆",
        "spiral_calendar": "🗓️",
        "spiral_notepad": "🗒️",
        "newspaper_cldr": "📰",
        "megaphone": "📣",
        "loudspeaker_cldr": "📢",

        // Symbols — CLDR names
        "check_mark": "✔️", "check_mark_button": "✅",
        "cross_mark": "❌", "cross_mark_button": "❎",
        "plus": "➕", "minus": "➖", "divide": "➗", "multiply": "✖️",
        "warning_cldr": "⚠️",
        "no_entry_cldr": "⛔", "prohibited": "🚫",
        "right_arrow": "➡️", "left_arrow": "⬅️",
        "up_arrow": "⬆️", "down_arrow": "⬇️",
        "recycling_symbol": "♻️",
        "hundred_points": "💯",
        "red_circle_cldr": "🔴", "blue_circle_cldr": "🔵",
        "white_circle_cldr": "⚪", "black_circle_cldr": "⚫",
        "red_question_mark": "❓", "white_question_mark": "❔",
        "red_exclamation_mark": "❗", "white_exclamation_mark": "❕",
    ]
}
