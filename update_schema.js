const fs = require('fs');

let pbSchema = JSON.parse(fs.readFileSync('pb_schema.json', 'utf8'));

pbSchema.push(
  {
    "id": "col_task_boards",
    "name": "task_boards",
    "type": "base",
    "system": false,
    "schema": [
      { "system": false, "id": "tbd_name", "name": "name", "type": "text", "required": true, "options": { "min": 1, "max": 100 } },
      { "system": false, "id": "tbd_desc", "name": "description", "type": "text", "required": false, "options": {} },
      { "system": false, "id": "tbd_owner", "name": "owner_id", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } },
      { "system": false, "id": "tbd_members", "name": "members", "type": "relation", "required": false, "options": { "collectionId": "_pb_users_auth_", "maxSelect": null } }
    ],
    "listRule": "@request.auth.id != '' && (owner_id = @request.auth.id || members ~ @request.auth.id)",
    "viewRule": "@request.auth.id != '' && (owner_id = @request.auth.id || members ~ @request.auth.id)",
    "createRule": "@request.auth.id != '' && owner_id = @request.auth.id",
    "updateRule": "@request.auth.id != '' && (owner_id = @request.auth.id || members ~ @request.auth.id)",
    "deleteRule": "@request.auth.id != '' && owner_id = @request.auth.id"
  },
  {
    "id": "col_task_lists",
    "name": "task_lists",
    "type": "base",
    "system": false,
    "schema": [
      { "system": false, "id": "tll_board", "name": "board_id", "type": "relation", "required": true, "options": { "collectionId": "col_task_boards", "cascadeDelete": true, "maxSelect": 1 } },
      { "system": false, "id": "tll_name", "name": "name", "type": "text", "required": true, "options": { "min": 1, "max": 100 } },
      { "system": false, "id": "tll_order", "name": "order", "type": "number", "required": true, "options": {} }
    ],
    "listRule": "@request.auth.id != ''",
    "viewRule": "@request.auth.id != ''",
    "createRule": "@request.auth.id != ''",
    "updateRule": "@request.auth.id != ''",
    "deleteRule": "@request.auth.id != ''"
  },
  {
    "id": "col_task_items",
    "name": "task_items",
    "type": "base",
    "system": false,
    "schema": [
      { "system": false, "id": "tsi_list", "name": "list_id", "type": "relation", "required": true, "options": { "collectionId": "col_task_lists", "cascadeDelete": true, "maxSelect": 1 } },
      { "system": false, "id": "tsi_title", "name": "title", "type": "text", "required": true, "options": { "min": 1, "max": 200 } },
      { "system": false, "id": "tsi_desc", "name": "description", "type": "text", "required": false, "options": {} },
      { "system": false, "id": "tsi_created", "name": "created_by", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": false, "maxSelect": 1 } },
      { "system": false, "id": "tsi_assignees", "name": "assignees", "type": "relation", "required": false, "options": { "collectionId": "_pb_users_auth_", "maxSelect": null } },
      { "system": false, "id": "tsi_due", "name": "due_date", "type": "date", "required": false, "options": {} },
      { "system": false, "id": "tsi_order", "name": "order", "type": "number", "required": false, "options": {} },
      { "system": false, "id": "tsi_completed", "name": "is_completed", "type": "bool", "required": false, "options": {} }
    ],
    "listRule": "@request.auth.id != ''",
    "viewRule": "@request.auth.id != ''",
    "createRule": "@request.auth.id != ''",
    "updateRule": "@request.auth.id != ''",
    "deleteRule": "@request.auth.id != ''"
  }
);

fs.writeFileSync('pb_schema.json', JSON.stringify(pbSchema, null, 2));
console.log('Done!');
