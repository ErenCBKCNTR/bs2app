const fs = require('fs');
let schema = JSON.parse(fs.readFileSync('pb_schema.json', 'utf8'));

// Dışarıdan veya içeriden bir koleksiyon varsa kontrol et
if (!schema.find(c => c.name === "friend_requests")) {
  schema.push({
    "id": "col_friend_reqs",
    "name": "friend_requests",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "frq_from",
        "name": "from_user",
        "type": "relation",
        "required": true,
        "options": {
          "collectionId": "_pb_users_auth_",
          "cascadeDelete": true,
          "maxSelect": 1
        }
      },
      {
        "system": false,
        "id": "frq_to",
        "name": "to_user",
        "type": "relation",
        "required": true,
        "options": {
          "collectionId": "_pb_users_auth_",
          "cascadeDelete": true,
          "maxSelect": 1
        }
      }
    ],
    "listRule": "@request.auth.id = from_user || @request.auth.id = to_user",
    "viewRule": "@request.auth.id = from_user || @request.auth.id = to_user",
    "createRule": "@request.auth.id = from_user",
    "updateRule": "@request.auth.id = to_user",
    "deleteRule": "@request.auth.id = from_user || @request.auth.id = to_user"
  });
}

if (!schema.find(c => c.name === "friendships")) {
    schema.push({
      "id": "col_friendships",
      "name": "friendships",
      "type": "base",
      "system": false,
      "schema": [
        {
          "system": false,
          "id": "frn_user1",
          "name": "user1",
          "type": "relation",
          "required": true,
          "options": {
            "collectionId": "_pb_users_auth_",
            "cascadeDelete": true,
            "maxSelect": 1
          }
        },
        {
          "system": false,
          "id": "frn_user2",
          "name": "user2",
          "type": "relation",
          "required": true,
          "options": {
            "collectionId": "_pb_users_auth_",
            "cascadeDelete": true,
            "maxSelect": 1
          }
        }
      ],
      "listRule": "@request.auth.id != ''",
      "viewRule": "@request.auth.id != ''",
      "createRule": "@request.auth.id != ''",
      "updateRule": "@request.auth.id != ''",
      "deleteRule": "@request.auth.id = user1 || @request.auth.id = user2"
    });
}

fs.writeFileSync('pb_schema.json', JSON.stringify(schema, null, 2));
console.log("Friend schema patches applied!");
