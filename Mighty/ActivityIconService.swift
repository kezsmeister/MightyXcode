import Foundation

struct ActivityIconService {
    /// Maps activity names to relevant SF Symbols
    static func icon(for activity: String) -> String {
        let lowercased = activity.lowercased()

        // Sports
        if lowercased.contains("soccer") || lowercased.contains("football") && !lowercased.contains("american") {
            return "soccerball"
        }
        if lowercased.contains("basketball") {
            return "basketball"
        }
        if lowercased.contains("tennis") {
            return "tennis.racket"
        }
        if lowercased.contains("baseball") || lowercased.contains("softball") {
            return "baseball"
        }
        if lowercased.contains("volleyball") {
            return "volleyball"
        }
        if lowercased.contains("hockey") {
            return "hockey.puck"
        }
        if lowercased.contains("golf") {
            return "figure.golf"
        }
        if lowercased.contains("swim") {
            return "figure.pool.swim"
        }
        if lowercased.contains("gymnast") {
            return "figure.gymnastics"
        }
        if lowercased.contains("jiu") || lowercased.contains("bjj") || lowercased.contains("judo") {
            return "figure.martial.arts"
        }
        if lowercased.contains("karate") || lowercased.contains("taekwondo") {
            return "figure.kickboxing"
        }
        if lowercased.contains("martial") {
            return "figure.martial.arts"
        }
        if lowercased.contains("boxing") {
            return "figure.boxing"
        }
        if lowercased.contains("wrestling") {
            return "figure.wrestling"
        }
        if lowercased.contains("fencing") {
            return "figure.fencing"
        }
        if lowercased.contains("archery") {
            return "figure.archery"
        }
        if lowercased.contains("skiing") || lowercased.contains("ski") {
            return "figure.skiing.downhill"
        }
        if lowercased.contains("snowboard") {
            return "figure.snowboarding"
        }
        if lowercased.contains("skating") || lowercased.contains("ice skating") {
            return "figure.skating"
        }
        if lowercased.contains("cycling") || lowercased.contains("biking") || lowercased.contains("bicycle") {
            return "bicycle"
        }
        if lowercased.contains("running") || lowercased.contains("track") || lowercased.contains("jogging") {
            return "figure.run"
        }
        if lowercased.contains("hiking") {
            return "figure.hiking"
        }
        if lowercased.contains("climbing") || lowercased.contains("rock climbing") {
            return "figure.climbing"
        }
        if lowercased.contains("rowing") {
            return "figure.rowing"
        }
        if lowercased.contains("surfing") {
            return "figure.surfing"
        }
        if lowercased.contains("badminton") {
            return "figure.badminton"
        }
        if lowercased.contains("table tennis") || lowercased.contains("ping pong") {
            return "figure.table.tennis"
        }
        if lowercased.contains("cricket") {
            return "cricket.ball"
        }
        if lowercased.contains("lacrosse") {
            return "figure.lacrosse"
        }
        if lowercased.contains("rugby") {
            return "rugbyball"
        }
        if lowercased.contains("american football") {
            return "football"
        }

        // Dance & Performance
        if lowercased.contains("ballet") {
            return "figure.dance"
        }
        if lowercased.contains("dance") || lowercased.contains("dancing") {
            return "figure.socialdance"
        }
        if lowercased.contains("theater") || lowercased.contains("theatre") || lowercased.contains("drama") || lowercased.contains("acting") {
            return "theatermasks"
        }
        if lowercased.contains("cheer") {
            return "figure.cheerleading"
        }

        // Music
        if lowercased.contains("piano") || lowercased.contains("keyboard") {
            return "pianokeys"
        }
        if lowercased.contains("guitar") {
            return "guitars"
        }
        if lowercased.contains("violin") || lowercased.contains("viola") || lowercased.contains("cello") {
            return "music.note"
        }
        if lowercased.contains("drum") {
            return "drum"
        }
        if lowercased.contains("singing") || lowercased.contains("choir") || lowercased.contains("vocal") {
            return "music.mic"
        }
        if lowercased.contains("band") || lowercased.contains("orchestra") {
            return "music.note.list"
        }
        if lowercased.contains("music") {
            return "music.quarternote.3"
        }
        if lowercased.contains("trumpet") || lowercased.contains("horn") || lowercased.contains("brass") {
            return "horn"
        }

        // Mind & Strategy
        if lowercased.contains("chess") {
            return "crown"
        }
        if lowercased.contains("coding") || lowercased.contains("programming") || lowercased.contains("computer") {
            return "laptopcomputer"
        }
        if lowercased.contains("robotics") || lowercased.contains("robot") {
            return "gear.badge"
        }
        if lowercased.contains("math") || lowercased.contains("mathletes") {
            return "x.squareroot"
        }
        if lowercased.contains("science") || lowercased.contains("chemistry") || lowercased.contains("lab") {
            return "flask"
        }
        if lowercased.contains("reading") || lowercased.contains("book club") {
            return "book"
        }
        if lowercased.contains("debate") || lowercased.contains("speech") || lowercased.contains("public speaking") {
            return "bubble.left.and.bubble.right"
        }
        if lowercased.contains("puzzle") {
            return "puzzlepiece"
        }
        if lowercased.contains("language") || lowercased.contains("spanish") || lowercased.contains("french") || lowercased.contains("chinese") || lowercased.contains("german") {
            return "character.bubble"
        }

        // Arts & Crafts
        if lowercased.contains("art") || lowercased.contains("painting") || lowercased.contains("drawing") {
            return "paintbrush"
        }
        if lowercased.contains("pottery") || lowercased.contains("ceramics") || lowercased.contains("sculpt") {
            return "hands.and.sparkles"
        }
        if lowercased.contains("photography") || lowercased.contains("photo") {
            return "camera"
        }
        if lowercased.contains("craft") || lowercased.contains("knitting") || lowercased.contains("sewing") {
            return "scissors"
        }
        if lowercased.contains("woodwork") || lowercased.contains("carpentry") {
            return "hammer"
        }

        // Fitness & Wellness
        if lowercased.contains("yoga") {
            return "figure.yoga"
        }
        if lowercased.contains("pilates") {
            return "figure.pilates"
        }
        if lowercased.contains("weight") || lowercased.contains("strength") || lowercased.contains("gym") || lowercased.contains("crossfit") {
            return "dumbbell"
        }
        if lowercased.contains("cardio") || lowercased.contains("aerobic") {
            return "heart.circle"
        }
        if lowercased.contains("hiit") || lowercased.contains("interval") {
            return "bolt.heart"
        }
        if lowercased.contains("meditation") || lowercased.contains("mindfulness") {
            return "brain.head.profile"
        }
        if lowercased.contains("stretch") {
            return "figure.flexibility"
        }

        // Outdoor & Nature
        if lowercased.contains("scout") || lowercased.contains("camping") {
            return "tent"
        }
        if lowercased.contains("garden") || lowercased.contains("plant") {
            return "leaf"
        }
        if lowercased.contains("fishing") {
            return "fish"
        }
        if lowercased.contains("horse") || lowercased.contains("riding") || lowercased.contains("equestrian") {
            return "figure.equestrian.sports"
        }
        if lowercased.contains("pet") || lowercased.contains("dog") || lowercased.contains("animal") {
            return "pawprint"
        }

        // Games & Recreation
        if lowercased.contains("video game") || lowercased.contains("gaming") || lowercased.contains("esport") {
            return "gamecontroller"
        }
        if lowercased.contains("board game") {
            return "dice"
        }
        if lowercased.contains("magic") || lowercased.contains("card") {
            return "suit.spade"
        }
        if lowercased.contains("bowling") {
            return "figure.bowling"
        }

        // School & Academic
        if lowercased.contains("tutor") || lowercased.contains("homework") || lowercased.contains("study") {
            return "pencil.and.list.clipboard"
        }
        if lowercased.contains("school") || lowercased.contains("class") || lowercased.contains("lesson") {
            return "graduationcap"
        }
        if lowercased.contains("exam") || lowercased.contains("test") {
            return "doc.text"
        }

        // Social & Community
        if lowercased.contains("volunteer") || lowercased.contains("community") {
            return "hand.raised"
        }
        if lowercased.contains("club") || lowercased.contains("meeting") {
            return "person.3"
        }
        if lowercased.contains("party") || lowercased.contains("birthday") || lowercased.contains("celebration") {
            return "party.popper"
        }
        if lowercased.contains("playdate") || lowercased.contains("friend") {
            return "figure.2.and.child.holdinghands"
        }

        // Medical & Health
        if lowercased.contains("doctor") || lowercased.contains("checkup") || lowercased.contains("appointment") {
            return "stethoscope"
        }
        if lowercased.contains("dentist") || lowercased.contains("dental") {
            return "mouth"
        }
        if lowercased.contains("therapy") || lowercased.contains("counseling") {
            return "heart.text.square"
        }

        // Travel & Transport
        if lowercased.contains("travel") || lowercased.contains("trip") || lowercased.contains("vacation") {
            return "airplane"
        }
        if lowercased.contains("driving") || lowercased.contains("car") {
            return "car"
        }

        // Default - return a generic activity icon
        return "figure.walk"
    }

    /// Get a color scheme for the activity
    static func colors(for activity: String) -> (primary: String, secondary: String) {
        let lowercased = activity.lowercased()

        // Sports - energetic colors
        if lowercased.contains("soccer") || lowercased.contains("football") || lowercased.contains("basketball") ||
           lowercased.contains("tennis") || lowercased.contains("baseball") || lowercased.contains("volleyball") ||
           lowercased.contains("hockey") || lowercased.contains("rugby") || lowercased.contains("lacrosse") {
            return ("orange", "red")
        }

        // Water sports - blue tones
        if lowercased.contains("swim") || lowercased.contains("rowing") || lowercased.contains("surfing") ||
           lowercased.contains("water") {
            return ("cyan", "blue")
        }

        // Dance & Performance - purple/pink
        if lowercased.contains("ballet") || lowercased.contains("dance") || lowercased.contains("theater") ||
           lowercased.contains("cheer") || lowercased.contains("drama") {
            return ("pink", "purple")
        }

        // Music - indigo
        if lowercased.contains("piano") || lowercased.contains("guitar") || lowercased.contains("violin") ||
           lowercased.contains("music") || lowercased.contains("drum") || lowercased.contains("singing") ||
           lowercased.contains("band") || lowercased.contains("orchestra") {
            return ("indigo", "purple")
        }

        // Mind & Strategy - teal
        if lowercased.contains("chess") || lowercased.contains("coding") || lowercased.contains("robotics") ||
           lowercased.contains("math") || lowercased.contains("science") || lowercased.contains("debate") {
            return ("teal", "cyan")
        }

        // Arts - warm colors
        if lowercased.contains("art") || lowercased.contains("painting") || lowercased.contains("pottery") ||
           lowercased.contains("craft") || lowercased.contains("photography") {
            return ("yellow", "orange")
        }

        // Fitness - green
        if lowercased.contains("yoga") || lowercased.contains("pilates") || lowercased.contains("weight") ||
           lowercased.contains("gym") || lowercased.contains("cardio") || lowercased.contains("running") {
            return ("green", "mint")
        }

        // Outdoor - natural greens
        if lowercased.contains("scout") || lowercased.contains("camping") || lowercased.contains("garden") ||
           lowercased.contains("hiking") || lowercased.contains("nature") {
            return ("green", "brown")
        }

        // Martial arts - red/black feel
        if lowercased.contains("martial") || lowercased.contains("karate") || lowercased.contains("taekwondo") || lowercased.contains("jiu") || lowercased.contains("bjj") ||
           lowercased.contains("boxing") || lowercased.contains("wrestling") {
            return ("red", "gray")
        }

        // Default - nice teal/green
        return ("teal", "green")
    }
}
