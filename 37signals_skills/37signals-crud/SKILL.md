---
name: 37signals-crud
description: Generate CRUD controllers following "everything is CRUD" philosophy. Create new resources for state changes. Triggers on controllers, CRUD, REST, routes, resourceful, state changes.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals CRUD Skill

## Overview

Translate any action into CRUD operations by creating new resources. Never add custom actions to controllers (no `member` or `collection` routes). Create new controllers for state changes.

## Core Philosophy

**Everything is CRUD.** When something doesn't fit standard CRUD, create a new resource.

## The Pattern

### Bad (custom actions):
```ruby
# ❌ DON'T DO THIS
resources :cards do
  post :close
  post :reopen
  post :gild
end
```

### Good (new resources):
```ruby
# ✅ DO THIS
resources :cards do
  resource :closure      # POST to close, DELETE to reopen
  resource :goldness     # POST to gild, DELETE to ungild
  resource :pin          # POST to pin, DELETE to unpin

  scope module: :cards do
    resources :comments
    resources :assignments
  end
end
```

## Resource Thinking

| User Request | Resource to Create |
|--------------|-------------------|
| "Close cards" | `Cards::ClosuresController` |
| "Mark important" | `Cards::GoldnessesController` |
| "Follow a card" | `Cards::WatchesController` |
| "Assign users" | `Cards::AssignmentsController` |
| "Publish boards" | `Boards::PublicationsController` |
| "Archive projects" | `Projects::ArchivalsController` |

## Controller Patterns

### Pattern 1: State Toggle (singular resource)

```ruby
# app/controllers/cards/closures_controller.rb
class Cards::ClosuresController < ApplicationController
  include CardScoped  # Provides @card

  def create
    @card.close(user: Current.user)
    render_card_replacement
  end

  def destroy
    @card.reopen
    render_card_replacement
  end
end
```

### Pattern 2: Standard CRUD (plural resources)

```ruby
# app/controllers/cards/comments_controller.rb
class Cards::CommentsController < ApplicationController
  include CardScoped

  def index
    @comments = @card.comments.recent
  end

  def create
    @comment = @card.comments.create!(comment_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @card }
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:body)
  end
end
```

### Pattern 3: Nested Resources

```ruby
# app/controllers/boards/columns_controller.rb
class Boards::ColumnsController < ApplicationController
  include BoardScoped

  def create
    @column = @board.columns.create!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @board }
    end
  end

  def destroy
    @column = @board.columns.find(params[:id])
    @column.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @board }
    end
  end
end
```

## Routing Patterns

### Singular resource for toggles:
```ruby
resource :closure, only: [:create, :destroy]
```

### Module scoping for organization:
```ruby
resources :cards do
  scope module: :cards do
    resources :comments
    resources :attachments
    resource :closure
  end
end
```

## Response Patterns

```ruby
def create
  @resource = Model.create!(resource_params)

  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to @resource }
    format.json { render json: @resource, status: :created }
  end
end

def destroy
  @resource.destroy!

  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to parent_path }
    format.json { head :no_content }
  end
end
```

## Scoping Concerns

```ruby
# app/controllers/concerns/card_scoped.rb
module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_card
  end

  private

  def set_card
    @card = Current.account.cards.find(params[:card_id])
  end
end
```

## Files to Create

When generating a new resource controller:

1. **Controller**: `app/controllers/[namespace]/[resource]_controller.rb`
2. **Route entry**: Add to `config/routes.rb`
3. **Test file**: `test/controllers/[namespace]/[resource]_controller_test.rb`
4. **Concern (if needed)**: `app/controllers/concerns/[resource]_scoped.rb`

## Commands

```bash
bin/rails routes | grep cards          # Check routes
bin/rails generate controller cards/closures  # Generate controller
bin/rails test test/controllers/       # Run tests
```

## Boundaries

### Always
- Map actions to CRUD (create/destroy for toggles)
- Create new resources for state changes
- Use concerns for scoping
- Use only 7 REST actions: index, show, new, create, edit, update, destroy
- Generate matching tests
- Use strong parameters

### Never
- Add custom actions (member/collection routes)
- Create controllers without tests
- Skip strong parameters
- Put business logic in controllers
