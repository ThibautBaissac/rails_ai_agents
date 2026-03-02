# Active Storage: Controllers, Service Methods, and Performance

## Controller: Single Upload

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def update
    if @user.update(user_params)
      redirect_to @user, notice: "Profile updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :avatar)
  end
end
```

## Controller: Multiple Uploads

```ruby
# app/controllers/events_controller.rb
class EventsController < ApplicationController
  def update
    if @event.update(event_params)
      redirect_to @event, notice: "Event updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def event_params
    params.require(:event).permit(:name, :description, photos: [], documents: [])
  end
end
```

## Controller: Removing Attachments

```ruby
class UsersController < ApplicationController
  def remove_avatar
    @user.avatar.purge
    redirect_to edit_user_path(@user), notice: "Avatar removed"
  end
end

# For Turbo Stream
def remove_avatar
  @user.avatar.purge
  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.remove("avatar-preview") }
    format.html { redirect_to edit_user_path(@user) }
  end
end
```

## Service Methods

```ruby
# Check if attached
user.avatar.attached?

# Get URL (requires controller context or url_for)
url_for(user.avatar)
rails_blob_path(user.avatar, disposition: "attachment")

# Get filename
user.avatar.filename.to_s

# Get content type
user.avatar.content_type

# Get byte size
user.avatar.byte_size
```

## Downloading / Streaming

```ruby
# In controller - redirect to blob URL
def download
  @document = Document.find(params[:id])
  redirect_to rails_blob_path(@document.file, disposition: "attachment")
end

# Or stream directly
def download
  @document = Document.find(params[:id])
  send_data @document.file.download,
            filename: @document.file.filename.to_s,
            content_type: @document.file.content_type
end
```

## Performance: Eager Loading

```ruby
# Prevent N+1 on attachments
User.with_attached_avatar.limit(10)

# Multiple attachments
Event.with_attached_photos.with_attached_documents
```

## Performance: Preloading Variants

```ruby
# In controller
@users = User.with_attached_avatar.limit(10)

# Preload variants
@users.each do |user|
  user.avatar.variant(:thumb).processed if user.avatar.attached?
end
```

## Direct Uploads

```javascript
// app/javascript/application.js
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
```

```erb
<%= form_with model: @event do |f| %>
  <%= f.file_field :photos, multiple: true, direct_upload: true %>
<% end %>
```

```css
/* app/assets/stylesheets/direct_uploads.css */
.direct-upload {
  display: inline-block;
  position: relative;
  padding: 2px 4px;
  margin: 0 3px 3px 0;
  border: 1px solid rgba(0, 0, 0, 0.3);
  border-radius: 3px;
  font-size: 11px;
  line-height: 13px;
}

.direct-upload--pending {
  opacity: 0.6;
}

.direct-upload__progress {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  opacity: 0.2;
  background: #0076ff;
  transition: width 120ms ease-out, opacity 60ms 60ms ease-in;
}

.direct-upload--complete .direct-upload__progress {
  opacity: 0.4;
}

.direct-upload--error {
  border-color: red;
}
```
