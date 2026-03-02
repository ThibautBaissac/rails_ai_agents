# Email Templates

## HTML Template

```erb
<%# app/views/user_mailer/welcome.html.erb %>
<h1><%= t(".greeting", name: @user.name) %></h1>

<p><%= t(".intro") %></p>

<p><%= t(".getting_started") %></p>

<ul>
  <li><%= t(".step_1") %></li>
  <li><%= t(".step_2") %></li>
  <li><%= t(".step_3") %></li>
</ul>

<p>
  <%= link_to t(".login_button"), @login_url, class: "button" %>
</p>

<p><%= t(".help_text_html", support_email: mail_to("support@example.com")) %></p>
```

## Text Template

```erb
<%# app/views/user_mailer/welcome.text.erb %>
<%= t(".greeting", name: @user.name) %>

<%= t(".intro") %>

<%= t(".getting_started") %>

* <%= t(".step_1") %>
* <%= t(".step_2") %>
* <%= t(".step_3") %>

<%= t(".login_prompt") %>: <%= @login_url %>

<%= t(".help_text", support_email: "support@example.com") %>
```

## Email Layout

```erb
<%# app/views/layouts/mailer.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width">
    <style>
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 600px;
        margin: 0 auto;
        padding: 20px;
      }
      .button {
        display: inline-block;
        padding: 12px 24px;
        background-color: #0066cc;
        color: #ffffff;
        text-decoration: none;
        border-radius: 4px;
      }
      .footer {
        margin-top: 40px;
        padding-top: 20px;
        border-top: 1px solid #eee;
        font-size: 12px;
        color: #666;
      }
    </style>
  </head>
  <body>
    <%= yield %>

    <div class="footer">
      <p><%= t("mailer.footer.company_name") %></p>
      <p><%= t("mailer.footer.address") %></p>
    </div>
  </body>
</html>
```
