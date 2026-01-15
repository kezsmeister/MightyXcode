import { i } from "@instantdb/core";

const _schema = i.schema({
  entities: {
    "$files": i.entity({
      "path": i.string().unique().indexed(),
      "url": i.string().optional(),
    }),
    "$users": i.entity({
      "email": i.string().unique().indexed().optional(),
      "imageURL": i.string().optional(),
      "type": i.string().optional(),
    }),
    "customEntries": i.entity({
      "date": i.string().optional(),
      "endDate": i.string().optional(),
      "endTime": i.string().optional(),
      "isRecurrenceTemplate": i.boolean().optional(),
      "localId": i.string().optional(),
      "notes": i.string().optional(),
      "notifyBefore": i.number().optional(),
      "rating": i.number().optional(),
      "recurrenceEndDate": i.string().optional(),
      "recurrenceGroupId": i.string().optional(),
      "recurrenceOccurrenceCount": i.number().optional(),
      "recurrencePatternRaw": i.string().optional(),
      "recurrenceWeekdays": i.json().optional(),
      "startTime": i.string().optional(),
      "title": i.string().optional(),
      "updatedAt": i.string().optional(),
    }),
    "customSections": i.entity({
      "icon": i.string().optional(),
      "localId": i.string().optional(),
      "name": i.string().optional(),
      "notificationsEnabled": i.boolean().optional(),
      "sortOrder": i.number().optional(),
      "suggestedActivities": i.json().optional(),
      "updatedAt": i.string().optional(),
    }),
    "kidProfiles": i.entity({
      "emoji": i.string().optional(),
      "enabledTemplates": i.json().optional(),
      "hasCompletedOnboarding": i.boolean().optional(),
      "localId": i.string().optional(),
      "name": i.string().optional(),
      "tabOrder": i.json().optional(),
      "updatedAt": i.string().optional(),
      "yearlyBookGoal": i.number().optional(),
      "yearlyMovieGoal": i.number().optional(),
    }),
    "mediaEntries": i.entity({
      "date": i.string().optional(),
      "endDate": i.string().optional(),
      "imageURL": i.string().optional(),
      "localId": i.string().optional(),
      "mediaTypeRaw": i.string().optional(),
      "notes": i.string().optional(),
      "rating": i.number().optional(),
      "title": i.string().optional(),
      "updatedAt": i.string().optional(),
      "videoTypeRaw": i.string().optional(),
    }),
  },
  links: {
    // kidProfiles belong to a user (parent)
    "kidProfilesParent": {
      "forward": {
        "on": "kidProfiles",
        "has": "one",
        "label": "parent"
      },
      "reverse": {
        "on": "$users",
        "has": "many",
        "label": "kidProfiles"
      }
    },
    // customSections belong to a kidProfile
    "customSectionsKidProfile": {
      "forward": {
        "on": "customSections",
        "has": "one",
        "label": "kidProfile"
      },
      "reverse": {
        "on": "kidProfiles",
        "has": "many",
        "label": "customSections"
      }
    },
    // mediaEntries belong to a kidProfile
    "mediaEntriesKidProfile": {
      "forward": {
        "on": "mediaEntries",
        "has": "one",
        "label": "kidProfile"
      },
      "reverse": {
        "on": "kidProfiles",
        "has": "many",
        "label": "mediaEntries"
      }
    },
    // customEntries belong to a customSection
    "customEntriesSection": {
      "forward": {
        "on": "customEntries",
        "has": "one",
        "label": "section"
      },
      "reverse": {
        "on": "customSections",
        "has": "many",
        "label": "customEntries"
      }
    },
  },
  rooms: {}
});

type _AppSchema = typeof _schema;
interface AppSchema extends _AppSchema {}
const schema: AppSchema = _schema;

export type { AppSchema }
export default schema;
