# Mailer Previews

Previews allow you to view emails in the browser during development.
Start the server and visit `/rails/mailers` to see all previews.

## Basic Preview

```ruby
# spec/mailers/previews/entity_mailer_preview.rb
class EntityMailerPreview < ActionMailer::Preview
  # Preview at: http://localhost:3000/rails/mailers/entity_mailer/created
  def created
    entity = Entity.first || FactoryBot.create(:entity)
    EntityMailer.created(entity)
  end

  # Preview at: http://localhost:3000/rails/mailers/entity_mailer/updated
  def updated
    entity = Entity.first || FactoryBot.create(:entity)
    EntityMailer.updated(entity)
  end

  # Preview at: http://localhost:3000/rails/mailers/entity_mailer/approved
  def approved
    entity = Entity.last || FactoryBot.create(:entity)
    EntityMailer.approved(entity)
  end
end
```

## Preview with Fake Data

Use unsaved objects to avoid touching the database and to control the preview content precisely.

```ruby
# spec/mailers/previews/submission_mailer_preview.rb
class SubmissionMailerPreview < ActionMailer::Preview
  def new_submission
    # Create temporary data for preview
    owner = User.new(
      id: 1,
      email: "owner@example.com",
      first_name: "Jane",
      last_name: "Smith"
    )

    entity = Entity.new(
      id: 1,
      name: "Test Entity",
      owner: owner
    )

    author = User.new(
      id: 2,
      email: "author@example.com",
      first_name: "John",
      last_name: "Doe"
    )

    submission = Submission.new(
      id: 1,
      rating: 5,
      content: "Excellent quality! Great service and attention to detail.",
      entity: entity,
      author: author
    )

    SubmissionMailer.new_submission(submission)
  end

  def submission_response
    submission = Submission.first || FactoryBot.create(:submission)
    response = "Thank you for your submission! We're glad to have your feedback."
    SubmissionMailer.submission_response(submission, response)
  end
end
```
