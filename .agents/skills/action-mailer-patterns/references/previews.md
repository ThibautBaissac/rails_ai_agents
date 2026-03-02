# Email Previews

Access previews at: `http://localhost:3000/rails/mailers`

## Basic Preview

```ruby
# spec/mailers/previews/user_mailer_preview.rb
# OR test/mailers/previews/user_mailer_preview.rb
class UserMailerPreview < ActionMailer::Preview
  def welcome
    user = User.first || FactoryBot.build(:user, name: "Preview User")
    UserMailer.welcome(user)
  end

  def password_reset
    user = User.first || FactoryBot.build(:user)
    UserMailer.password_reset(user, "preview-token-123")
  end
end
```

## Preview with Different States

```ruby
class OrderMailerPreview < ActionMailer::Preview
  def confirmation
    order = Order.last || build_preview_order
    OrderMailer.confirmation(order)
  end

  def confirmation_with_discount
    order = build_preview_order
    order.discount_cents = 1000
    OrderMailer.confirmation(order)
  end

  def confirmation_multiple_items
    order = build_preview_order
    3.times { order.line_items.build(product: Product.first, quantity: 2) }
    OrderMailer.confirmation(order)
  end

  private

  def build_preview_order
    Order.new(
      user: User.first,
      total_cents: 5000,
      created_at: Time.current
    )
  end
end
```
