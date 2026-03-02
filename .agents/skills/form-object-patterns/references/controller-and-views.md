# Controller and View Integration

## Controller

```ruby
# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    @form = RegistrationForm.new
  end

  def create
    @form = RegistrationForm.new(registration_params)

    if @form.save
      start_new_session_for(@form.user)
      redirect_to dashboard_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:registration).permit(
      :email, :password, :password_confirmation,
      :company_name, :phone
    )
  end
end
```

## Registration Form View

```erb
<%# app/views/registrations/new.html.erb %>
<%= form_with model: @form, url: registrations_path do |f| %>
  <% if @form.errors.any? %>
    <div class="alert alert-error">
      <ul>
        <% @form.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="field">
    <%= f.label :email %>
    <%= f.email_field :email, autofocus: true %>
  </div>

  <div class="field">
    <%= f.label :password %>
    <%= f.password_field :password %>
  </div>

  <div class="field">
    <%= f.label :password_confirmation %>
    <%= f.password_field :password_confirmation %>
  </div>

  <div class="field">
    <%= f.label :company_name %>
    <%= f.text_field :company_name %>
  </div>

  <%= f.submit "Register" %>
<% end %>
```

## Search Form View

```erb
<%# app/views/events/_search_form.html.erb %>
<%= form_with model: @search_form, url: events_path, method: :get, local: true do |f| %>
  <div class="flex gap-4">
    <%= f.search_field :query, placeholder: "Search events..." %>
    <%= f.select :event_type, @search_form.event_type_options, include_blank: "All types" %>
    <%= f.select :status, @search_form.status_options, include_blank: "All statuses" %>
    <%= f.date_field :start_date %>
    <%= f.date_field :end_date %>
    <%= f.submit "Search" %>

    <% if @search_form.any_filters? %>
      <%= link_to "Clear", events_path, class: "btn-secondary" %>
    <% end %>
  </div>
<% end %>
```
