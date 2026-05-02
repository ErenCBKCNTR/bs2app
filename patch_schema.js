const fs = require('fs');
let schema = JSON.parse(fs.readFileSync('pb_schema.json', 'utf8'));

schema.forEach(col => {
    let cname = col.name;

    if (cname === "messages") {
        col.listRule = "@collection.chat_participants.chat_id ?= chat_id && @collection.chat_participants.user_id ?= @request.auth.id || sender_id = @request.auth.id";
        col.viewRule = "@collection.chat_participants.chat_id ?= chat_id && @collection.chat_participants.user_id ?= @request.auth.id || sender_id = @request.auth.id";
        col.createRule = "@request.auth.id = sender_id";
        col.updateRule = "@request.auth.id = sender_id";
        col.deleteRule = "@request.auth.id = sender_id";
    }
    else if (cname === "chat_participants") {
        col.listRule = "user_id = @request.auth.id || @collection.chat_participants.chat_id ?= chat_id && @collection.chat_participants.user_id ?= @request.auth.id";
        col.viewRule = "user_id = @request.auth.id || @collection.chat_participants.chat_id ?= chat_id && @collection.chat_participants.user_id ?= @request.auth.id";
        col.createRule = "@request.auth.id != ''";
        col.updateRule = "user_id = @request.auth.id";
        col.deleteRule = "user_id = @request.auth.id";
    }
    else if (cname === "chats") {
        col.listRule = "@collection.chat_participants.chat_id ?= id && @collection.chat_participants.user_id ?= @request.auth.id || created_by = @request.auth.id";
        col.viewRule = "@collection.chat_participants.chat_id ?= id && @collection.chat_participants.user_id ?= @request.auth.id || created_by = @request.auth.id";
        col.updateRule = "created_by = @request.auth.id";
    }
    else if (cname === "task_boards") {
        col.listRule = "owner_id = @request.auth.id || members ~ @request.auth.id";
        col.viewRule = "owner_id = @request.auth.id || members ~ @request.auth.id";
        col.updateRule = "owner_id = @request.auth.id || members ~ @request.auth.id";
        col.deleteRule = "owner_id = @request.auth.id";
    }
    else if (cname === "task_comments") {
        col.updateRule = "user_id = @request.auth.id";
        col.deleteRule = "user_id = @request.auth.id";
    }
    else if (cname === "posts") {
        col.updateRule = "user_id = @request.auth.id";
        col.deleteRule = "user_id = @request.auth.id";
    }
    else if (cname === "post_comments") {
        col.updateRule = "user_id = @request.auth.id";
        col.deleteRule = "user_id = @request.auth.id || post_id.user_id = @request.auth.id";
    }
    else if (cname === "post_likes") {
        col.updateRule = "user_id = @request.auth.id";
        col.deleteRule = "user_id = @request.auth.id || post_id.user_id = @request.auth.id";
    }
    else if (cname === "server_memberships") {
        col.updateRule = "user_id = @request.auth.id";
        col.deleteRule = "user_id = @request.auth.id";
    }
    else if (cname === "server_messages") {
        col.listRule = "@request.auth.id != '' && @collection.server_memberships.server_id ?= room_id.server_id && @collection.server_memberships.user_id ?= @request.auth.id";
        col.viewRule = "@request.auth.id != '' && @collection.server_memberships.server_id ?= room_id.server_id && @collection.server_memberships.user_id ?= @request.auth.id";
        col.createRule = "@request.auth.id = sender_id";
        col.updateRule = "@request.auth.id = sender_id";
        col.deleteRule = "@request.auth.id = sender_id";
    }
});

fs.writeFileSync('pb_schema.json', JSON.stringify(schema, null, 2));
console.log("Schema rules patched!");
