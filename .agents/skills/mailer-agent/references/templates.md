# Email Templates

## HTML Layout

```erb
<%# app/views/layouts/mailer.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 600px;
        margin: 0 auto;
        padding: 20px;
      }
      .header {
        background-color: #4F46E5;
        color: white;
        padding: 20px;
        text-align: center;
        border-radius: 8px 8px 0 0;
      }
      .content {
        background-color: #ffffff;
        padding: 30px;
        border: 1px solid #e5e7eb;
      }
      .button {
        display: inline-block;
        padding: 12px 24px;
        background-color: #4F46E5;
        color: white !important;
        text-decoration: none;
        border-radius: 6px;
        margin: 20px 0;
      }
      .footer {
        text-align: center;
        padding: 20px;
        color: #6b7280;
        font-size: 12px;
      }
    </style>
  </head>
  <body>
    <div class="header">
      <h1>AITemplate</h1>
    </div>
    <div class="content">
      <%= yield %>
    </div>
    <div class="footer">
      <p>© <%= Time.current.year %> MyApp. All rights reserved.</p>
      <p>
        <%= link_to "Unsubscribe", unsubscribe_url, style: "color: #6b7280;" %>
      </p>
    </div>
  </body>
</html>
```

## Text Layout

```erb
<%# app/views/layouts/mailer.text.erb %>
===============================================
MyApp
===============================================

<%= yield %>

---
© <%= Time.current.year %> MyApp
To unsubscribe: <%= unsubscribe_url %>
```

## HTML Email Template

```erb
<%# app/views/entity_mailer/created.html.erb %>
<h2>Congratulations <%= @owner.first_name %>!</h2>

<p>
  Your entity <strong><%= @entity.name %></strong> has been successfully created.
</p>

<p>
  You can now:
</p>

<ul>
  <li>Add items to your collection</li>
  <li>Customize your entity page</li>
  <li>Respond to user submissions</li>
</ul>

<%= link_to "Manage my entity", entity_url(@entity), class: "button" %>

<p>
  <strong>Details:</strong><br>
  Address: <%= @entity.address %><br>
  Phone: <%= @entity.phone %>
</p>

<p>
  If you have any questions, feel free to contact us at
  <%= mail_to "support@example.com" %>.
</p>
```

## Text Email Template

```erb
<%# app/views/entity_mailer/created.text.erb %>
Congratulations <%= @owner.first_name %>!

Your entity <%= @entity.name %> has been successfully created.

You can now:
- Add items to your collection
- Customize your entity page
- Respond to user submissions

Manage my entity: <%= entity_url(@entity) %>

Details:
Address: <%= @entity.address %>
Phone: <%= @entity.phone %>

If you have any questions, contact us at support@example.com.
```
