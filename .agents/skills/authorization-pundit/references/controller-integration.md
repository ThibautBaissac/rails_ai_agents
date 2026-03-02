# Controller Integration

## ApplicationController Setup

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = t("pundit.not_authorized")
    redirect_back(fallback_location: root_path)
  end
end
```

## Basic CRUD Controller

```ruby
# app/controllers/events_controller.rb
class EventsController < ApplicationController
  def index
    @events = policy_scope(Event)
  end

  def show
    @event = Event.find(params[:id])
    authorize @event
  end

  def new
    @event = current_account.events.build
    authorize @event
  end

  def create
    @event = current_account.events.build(event_params)
    authorize @event

    if @event.save
      redirect_to @event, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @event = Event.find(params[:id])
    authorize @event
  end

  def update
    @event = Event.find(params[:id])
    authorize @event

    if @event.update(event_params)
      redirect_to @event, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event = Event.find(params[:id])
    authorize @event
    @event.destroy
    redirect_to events_path, notice: t(".success")
  end
end
```

## Custom Action Authorization

```ruby
class EventsController < ApplicationController
  def publish
    @event = Event.find(params[:id])
    authorize @event, :publish?

    if @event.publish!
      redirect_to @event, notice: t(".success")
    else
      redirect_to @event, alert: t(".failure")
    end
  end

  def duplicate
    @event = Event.find(params[:id])
    authorize @event, :duplicate?

    @new_event = @event.duplicate
    redirect_to edit_event_path(@new_event)
  end
end
```

## Skip Authorization

```ruby
class HomeController < ApplicationController
  skip_after_action :verify_authorized, only: [:index, :about]
  skip_after_action :verify_policy_scoped, only: [:index, :about]

  def index
    # Public page, no authorization needed
  end
end
```
