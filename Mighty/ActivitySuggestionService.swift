import Foundation

struct ActivitySuggestionService {

    private static let suggestionDatabase: [String: [String]] = [
        // Kids activities
        "kids": ["Karate", "Ballet", "Piano lessons", "Chess club", "Swimming",
                 "Soccer practice", "Art class", "Gymnastics", "Coding class", "Dance class"],
        "children": ["Karate", "Ballet", "Piano lessons", "Chess club", "Swimming",
                    "Soccer practice", "Art class", "Gymnastics", "Coding class", "Dance class"],
        "child": ["Karate", "Ballet", "Piano lessons", "Chess club", "Swimming",
                  "Soccer practice", "Art class", "Gymnastics", "Coding class", "Dance class"],
        "kid": ["Karate", "Ballet", "Piano lessons", "Chess club", "Swimming",
                "Soccer practice", "Art class", "Gymnastics", "Coding class", "Dance class"],
        "extracurricular": ["Karate", "Ballet", "Piano lessons", "Chess club", "Swimming",
                           "Soccer practice", "Art class", "Gymnastics", "Debate club", "Drama class"],

        // Fitness/Workouts
        "workout": ["Weight training", "Cardio", "HIIT", "Yoga", "Pilates",
                   "Running", "Swimming", "Cycling", "CrossFit", "Boxing"],
        "exercise": ["Weight training", "Cardio", "HIIT", "Yoga", "Pilates",
                    "Running", "Swimming", "Cycling", "CrossFit", "Boxing"],
        "fitness": ["Weight training", "Cardio", "HIIT", "Yoga", "Pilates",
                   "Running", "Swimming", "Cycling", "CrossFit", "Boxing"],
        "gym": ["Bench press", "Squats", "Deadlifts", "Pull-ups", "Rowing",
               "Treadmill", "Elliptical", "Leg press", "Shoulder press", "Core workout"],
        "training": ["Strength training", "Cardio session", "Flexibility", "Endurance", "Speed work",
                    "Recovery day", "Interval training", "Circuit training", "Warm-up", "Cool-down"],

        // Hobbies
        "hobby": ["Photography", "Painting", "Knitting", "Gardening", "Cooking",
                 "Writing", "Reading", "Gaming", "Woodworking", "Pottery"],
        "hobbies": ["Photography", "Painting", "Knitting", "Gardening", "Cooking",
                   "Writing", "Reading", "Gaming", "Woodworking", "Pottery"],
        "craft": ["Knitting", "Crocheting", "Sewing", "Embroidery", "Quilting",
                 "Jewelry making", "Candle making", "Paper crafts", "Pottery", "Woodworking"],
        "creative": ["Drawing", "Painting", "Sculpting", "Digital art", "Photography",
                    "Writing", "Music composition", "Crafting", "Design", "Calligraphy"],

        // Learning
        "learn": ["Online course", "Language study", "Reading", "Practice session",
                 "Tutorial", "Workshop", "Lecture", "Study group", "Certification prep", "Skill practice"],
        "study": ["Online course", "Language study", "Reading", "Practice session",
                 "Tutorial", "Workshop", "Lecture", "Study group", "Certification prep", "Homework"],
        "education": ["Lecture", "Seminar", "Workshop", "Tutorial", "Self-study",
                     "Group study", "Research", "Reading", "Practice test", "Review session"],
        "language": ["Vocabulary practice", "Grammar study", "Listening practice", "Speaking practice",
                    "Reading practice", "Writing practice", "Flashcards", "Language app", "Conversation", "Lesson"],

        // Music
        "music": ["Piano practice", "Guitar practice", "Singing", "Drums", "Violin",
                 "Music theory", "Composition", "Band rehearsal", "Lesson", "Recording"],
        "instrument": ["Practice session", "Lesson", "Scales", "Sight reading",
                      "Theory study", "Performance", "Rehearsal", "Recording", "Improvisation", "Ear training"],
        "piano": ["Scales", "Arpeggios", "Sight reading", "Technique", "Repertoire",
                 "Music theory", "Lesson", "Practice", "Performance prep", "Ear training"],
        "guitar": ["Chord practice", "Scales", "Fingerpicking", "Strumming", "Songs",
                  "Theory", "Lesson", "Jamming", "Recording", "Technique"],

        // Sports
        "sport": ["Basketball", "Football", "Soccer", "Tennis", "Golf",
                 "Baseball", "Hockey", "Volleyball", "Badminton", "Table tennis"],
        "sports": ["Basketball", "Football", "Soccer", "Tennis", "Golf",
                  "Baseball", "Hockey", "Volleyball", "Badminton", "Table tennis"],
        "team": ["Practice", "Game", "Scrimmage", "Training", "Warm-up",
                "Drills", "Strategy session", "Team meeting", "Conditioning", "Skills work"],

        // Health & Wellness
        "health": ["Meditation", "Yoga", "Stretching", "Walking", "Sleep tracking",
                  "Meal prep", "Hydration", "Vitamins", "Check-up", "Mental health break"],
        "wellness": ["Meditation", "Yoga", "Journaling", "Gratitude practice", "Breathing exercises",
                    "Self-care", "Massage", "Spa day", "Nature walk", "Digital detox"],
        "meditation": ["Morning meditation", "Guided meditation", "Breathing exercises", "Mindfulness",
                      "Body scan", "Walking meditation", "Evening wind-down", "Gratitude", "Visualization", "Mantra"],

        // Work/Productivity
        "work": ["Deep work session", "Meetings", "Email", "Planning", "Review",
                "Brainstorming", "Presentation prep", "Report writing", "Networking", "Training"],
        "productivity": ["Deep work", "Pomodoro session", "Planning", "Review", "Inbox zero",
                        "Task batch", "Learning block", "Creative time", "Admin tasks", "Weekly review"],
        "project": ["Planning", "Research", "Development", "Testing", "Review",
                   "Documentation", "Meeting", "Presentation", "Milestone", "Deadline"],

        // Pets
        "pet": ["Walk", "Feeding", "Grooming", "Vet visit", "Training session",
               "Playtime", "Bath", "Nail trim", "Medication", "Check-up"],
        "dog": ["Morning walk", "Evening walk", "Feeding", "Training", "Grooming",
               "Vet visit", "Playtime", "Bath", "Nail trim", "Dog park"],
        "cat": ["Feeding", "Litter cleaning", "Playtime", "Grooming", "Vet visit",
               "Medication", "Nail trim", "Brushing", "Interactive play", "Check-up"],

        // Home
        "home": ["Cleaning", "Laundry", "Dishes", "Vacuuming", "Organizing",
                "Maintenance", "Gardening", "Repairs", "Decluttering", "Deep clean"],
        "chores": ["Cleaning", "Laundry", "Dishes", "Vacuuming", "Mopping",
                  "Dusting", "Organizing", "Trash", "Grocery shopping", "Meal prep"],
        "garden": ["Watering", "Weeding", "Planting", "Pruning", "Fertilizing",
                  "Harvesting", "Composting", "Mulching", "Pest control", "Planning"]
    ]

    static func generateSuggestions(for description: String) -> [String] {
        let lowercased = description.lowercased()
        var matchedSuggestions: Set<String> = []

        // Find matching keywords
        for (keyword, suggestions) in suggestionDatabase {
            if lowercased.contains(keyword) {
                matchedSuggestions.formUnion(suggestions)
            }
        }

        // If no matches, provide generic activity suggestions
        if matchedSuggestions.isEmpty {
            matchedSuggestions = Set([
                "Activity 1", "Activity 2", "Activity 3", "Activity 4", "Activity 5",
                "Morning routine", "Evening routine", "Weekly review", "Practice", "Session"
            ])
        }

        // Return up to 10 suggestions, sorted alphabetically
        return Array(matchedSuggestions.prefix(10)).sorted()
    }

    static func extractSectionName(from description: String) -> String {
        // Remove common filler words
        let fillerWords = ["track", "my", "log", "record", "the", "a", "an", "for", "to", "i", "want"]
        var words = description.lowercased().components(separatedBy: .whitespaces)
        words = words.filter { !fillerWords.contains($0) && !$0.isEmpty }

        // Capitalize and join
        let name = words.map { $0.capitalized }.joined(separator: " ")
        return name.isEmpty ? "Custom Section" : name
    }
}
