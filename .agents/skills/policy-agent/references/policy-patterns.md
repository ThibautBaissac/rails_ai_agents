# Pundit Policy Patterns Reference

## ApplicationPolicy Base Class

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
```

## 1. Basic CRUD Policy

```ruby
# app/policies/entity_policy.rb
class EntityPolicy < ApplicationPolicy
  def index?
    true # Everyone can see the list
  end

  def show?
    true # Everyone can see an entity
  end

  def create?
    user.present? # Only authenticated users
  end

  def update?
    user.present? && owner?
  end

  def destroy?
    user.present? && owner?
  end

  def permitted_attributes
    if owner?
      [:name, :description, :address, :phone, :email, :website, :status]
    else
      []
    end
  end

  class Scope < Scope
    def resolve
      scope.published
    end
  end

  private

  def owner?
    record.user_id == user.id
  end
end
```

## 2. Policy with Roles

```ruby
# app/policies/submission_policy.rb
class SubmissionPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present? && !already_submitted?
  end

  def update?
    return false unless user.present?

    author? || admin?
  end

  def destroy?
    return false unless user.present?

    author? || admin? || entity_owner?
  end

  # Custom actions
  def moderate?
    user.present? && (admin? || entity_owner?)
  end

  def approve?
    admin?
  end

  def flag?
    user.present?
  end

  def permitted_attributes
    if author? || user.present?
      [:rating, :content, :submitted_date, :recommend]
    else
      []
    end
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.approved
      end
    end
  end

  private

  def author?
    record.user_id == user.id
  end

  def admin?
    user.admin?
  end

  def entity_owner?
    record.entity.user_id == user.id
  end

  def already_submitted?
    Submission.exists?(user: user, entity: record.entity)
  end
end
```

## 3. Policy with Complex Logic

```ruby
# app/policies/item_policy.rb
class ItemPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present? && entity_owner?
  end

  def update?
    user.present? && (entity_owner? || admin?)
  end

  def destroy?
    user.present? && entity_owner? && !has_dependencies?
  end

  def toggle_availability?
    user.present? && entity_owner?
  end

  def duplicate?
    create?
  end

  def reorder?
    user.present? && entity_owner?
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user.present?
        scope.where(entity: user.entities)
             .or(scope.where(available: true))
      else
        scope.available
      end
    end
  end

  private

  def entity_owner?
    record.entity.user_id == user.id
  end

  def admin?
    user.admin?
  end

  def has_dependencies?
    record.related_records.exists?
  end
end
```

## 4. Policy with Temporal Conditions

```ruby
# app/policies/booking_policy.rb
class BookingPolicy < ApplicationPolicy
  def create?
    user.present? && entity_accepts_bookings? && not_in_past?
  end

  def show?
    user.present? && (owner? || entity_owner? || admin?)
  end

  def update?
    return false unless user.present?
    return false if in_past?

    owner? && can_still_modify?
  end

  def cancel?
    return false unless user.present?
    return false if in_past?

    (owner? && can_still_cancel?) || entity_owner? || admin?
  end

  def confirm?
    user.present? && (entity_owner? || admin?)
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user.present?
        scope.where(user: user)
             .or(scope.where(entity: user.entities))
      else
        scope.none
      end
    end
  end

  private

  def owner?
    record.user_id == user.id
  end

  def entity_owner?
    record.entity.user_id == user.id
  end

  def admin?
    user.admin?
  end

  def entity_accepts_bookings?
    record.entity.accepts_bookings?
  end

  def not_in_past?
    record.booking_date >= Date.current
  end

  def in_past?
    record.booking_date < Date.current
  end

  def can_still_modify?
    record.booking_datetime > 2.hours.from_now
  end

  def can_still_cancel?
    record.booking_datetime > 4.hours.from_now
  end
end
```

## 5. Policy for Administrative Actions

```ruby
# app/policies/user_policy.rb
class UserPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    user.present? && (owner? || admin?)
  end

  def create?
    true # Public registration
  end

  def update?
    user.present? && (owner? || admin?)
  end

  def destroy?
    admin? && !owner? # Admin cannot delete themselves
  end

  def suspend?
    admin? && !owner?
  end

  def promote_to_admin?
    admin? && !owner?
  end

  def impersonate?
    admin? && !owner?
  end

  def export_data?
    owner? || admin?
  end

  def permitted_attributes
    if admin?
      [:email, :first_name, :last_name, :role, :suspended]
    elsif owner?
      [:email, :first_name, :last_name, :bio, :avatar]
    else
      []
    end
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user.present?
        scope.where(id: user.id)
      else
        scope.none
      end
    end
  end

  private

  def owner?
    record.id == user.id
  end

  def admin?
    user.admin?
  end
end
```
