# Mailer Templates Reference

## Template Conventions

- Always create both `.text.erb` and `.html.erb` versions
- HTML uses inline CSS only (no external stylesheets, no `<link>` tags)
- Keep HTML minimal -- table-based layout for email client compatibility
- Include action context in subject lines (who did what, where)
- Add unsubscribe links in footer
- Plain text version should be fully readable without HTML

## Mention Email

```erb
<%# app/views/comment_mailer/mentioned.text.erb %>
Hi <%= @mention.user.name %>,

<%= @mention.creator.name %> mentioned you in a comment on <%= @card.title %>:

"<%= @comment.body %>"

View the card: <%= account_board_card_url(@account, @card.board, @card) %>

---
You're receiving this because you were mentioned.

<%# app/views/comment_mailer/mentioned.html.erb %>
<p>Hi <%= @mention.user.name %>,</p>

<p><%= @mention.creator.name %> mentioned you in a comment on
   <strong><%= @card.title %></strong>:</p>

<blockquote style="border-left: 3px solid #ccc; padding-left: 15px; color: #666;">
  <%= simple_format(@comment.body) %>
</blockquote>

<p>
  <%= link_to "View the card",
      account_board_card_url(@account, @card.board, @card),
      style: "color: #0066cc; text-decoration: none;" %>
</p>

<p style="color: #999; font-size: 12px; margin-top: 30px;">
  You're receiving this because you were mentioned.
</p>
```

## Invitation Email

```erb
<%# app/views/membership_mailer/invitation.text.erb %>
Hi <%= @membership.user.name %>,

<%= @inviter.name %> has invited you to join <%= @account.name %>.

Accept invitation: <%= account_url(@account) %>

If you don't want to join, you can ignore this email.

<%# app/views/membership_mailer/invitation.html.erb %>
<p>Hi <%= @membership.user.name %>,</p>

<p><%= @inviter.name %> has invited you to join
   <strong><%= @account.name %></strong>.</p>

<p>
  <%= link_to "Accept invitation", account_url(@account),
      style: "display: inline-block; padding: 10px 20px; background: #0066cc;
             color: white; text-decoration: none; border-radius: 4px;" %>
</p>

<p style="color: #999; font-size: 12px; margin-top: 30px;">
  If you don't want to join, you can ignore this email.
</p>
```

## Magic Link / Sign-In Email

```erb
<%# app/views/magic_link_mailer/sign_in.text.erb %>
Hi <%= @user.name %>,

Click the link below to sign in to your account:

<%= magic_link_url(@magic_link.token) %>

This link will expire in 15 minutes.

If you didn't request this, you can safely ignore this email.

<%# app/views/magic_link_mailer/sign_in.html.erb %>
<p>Hi <%= @user.name %>,</p>

<p>Click the button below to sign in to your account:</p>

<p>
  <%= link_to "Sign in", magic_link_url(@magic_link.token),
      style: "display: inline-block; padding: 12px 24px; background: #0066cc;
             color: white; text-decoration: none; border-radius: 4px;
             font-weight: bold;" %>
</p>

<p style="color: #999; font-size: 12px;">
  This link will expire in 15 minutes.
</p>

<p style="color: #999; font-size: 12px; margin-top: 30px;">
  If you didn't request this, you can safely ignore this email.
</p>
```

## Email Layout

```erb
<%# app/views/layouts/mailer.text.erb %>
<%= yield %>

---
<%= @account&.name || "Example App" %>
<%= root_url %>

<%# app/views/layouts/mailer.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body {
        margin: 0; padding: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                     "Helvetica Neue", Arial, sans-serif;
        font-size: 16px; line-height: 1.5; color: #333; background: #f5f5f5;
      }
      table { border-collapse: collapse; }
      a { color: #0066cc; }
    </style>
  </head>
  <body>
    <table style="width: 100%; max-width: 600px; margin: 0 auto;" role="presentation">
      <tr>
        <td style="background: white; padding: 40px 30px;">
          <%= yield %>
        </td>
      </tr>
      <tr>
        <td style="padding: 20px 30px; text-align: center; color: #999; font-size: 12px;">
          <%= @account&.name || "Example App" %><br>
          <%= link_to root_url, root_url %>
          <% if @account && @user %>
            <br><br>
            <%= link_to "Unsubscribe",
                unsubscribe_url(token: @user.unsubscribe_token,
                                account_id: @account.id),
                style: "color: #999;" %>
          <% end %>
        </td>
      </tr>
    </table>
  </body>
</html>
```

## Button Styles

Standard CTA button (inline CSS for email clients):

```erb
<%= link_to "Action Text", url,
    style: "display: inline-block; padding: 10px 20px;
           background: #0066cc; color: white;
           text-decoration: none; border-radius: 4px;" %>
```

Bold/prominent button:

```erb
<%= link_to "Sign In", url,
    style: "display: inline-block; padding: 12px 24px;
           background: #0066cc; color: white;
           text-decoration: none; border-radius: 4px;
           font-weight: bold;" %>
```

## Email Previews

```ruby
class CommentMailerPreview < ActionMailer::Preview
  def mentioned
    mention = Mention.first || create_sample_mention
    CommentMailer.mentioned(mention)
  end

  def new_comment
    comment = Comment.first
    recipient = User.first
    CommentMailer.new_comment(comment, recipient)
  end

  private

  def create_sample_mention
    user = User.first
    account = Account.first
    board = account.boards.first
    card = board.cards.first
    comment = card.comments.create!(body: "Hey @alice", creator: user, account: account)
    Mention.create!(user: user, comment: comment, creator: user, account: account)
  end
end

class DigestMailerPreview < ActionMailer::Preview
  def daily_activity
    user = User.first
    account = Account.first
    activities = Activity.where(account: account).limit(10)
    DigestMailer.daily_activity(user, account, activities)
  end
end
```

Visit at: `http://localhost:3000/rails/mailers`
