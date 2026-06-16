import std/json


proc news_UserList*(): JsonNode =
  result = %*{
    "news": [
      {
        "newsGroupId": 1000516,
        "priority": 1000584,
        "category": 1,
        "title": "[Updated 4/24] Instructions for Adjusting Graphic Settings",
        "startAt": "2025-04-24T08:00:00Z",
        "editedAt": "2025-04-18T03:00:00Z"
      },
      {
        "newsGroupId": 1002945,
        "priority": 1000270,
        "category": 4,
        "title": "Standard Synchro \"Embarking Companionship\" - Now Available!",
        "startAt": "2025-04-18T03:00:00Z",
        "editedAt": "2025-02-26T07:00:00Z"
      },
      {
        "newsGroupId": 1002955,
        "priority": 1003014,
        "category": 2,
        "title": "[Updated 4/25]  Regarding Currently Known Issues",
        "startAt": "2025-04-25T11:25:00Z",
        "editedAt": "2025-02-20T02:00:00Z"
      }
    ]
  }