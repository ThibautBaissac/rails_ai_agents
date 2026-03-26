# Jbuilder Templates Reference

## Basic Patterns

### Index View

```ruby
# app/views/boards/index.json.jbuilder
json.array! @boards do |board|
  json.id board.id
  json.name board.name
  json.description board.description
  json.created_at board.created_at
  json.updated_at board.updated_at

  json.creator do
    json.id board.creator.id
    json.name board.creator.name
    json.email board.creator.email
  end

  json.url board_url(board, format: :json)
end
```

### Show View

```ruby
# app/views/boards/show.json.jbuilder
json.id @board.id
json.name @board.name
json.description @board.description
json.created_at @board.created_at
json.updated_at @board.updated_at

json.creator do
  json.id @board.creator.id
  json.name @board.creator.name
  json.email @board.creator.email
end

json.columns @board.columns do |column|
  json.id column.id
  json.name column.name
  json.position column.position
end

json.cards @board.cards do |card|
  json.id card.id
  json.title card.title
  json.column_id card.column_id
  json.url board_card_url(@board, card, format: :json)
end

json.url board_url(@board, format: :json)
```

## extract! Helper

Pull multiple attributes at once:

```ruby
json.extract! @board, :id, :name, :description, :created_at, :updated_at
```

## Partials

Reuse JSON templates like ERB partials:

```ruby
# app/views/cards/_card.json.jbuilder
json.id card.id
json.title card.title
json.description card.description
json.created_at card.created_at
json.updated_at card.updated_at

json.creator do
  json.id card.creator.id
  json.name card.creator.name
end

json.column do
  json.id card.column.id
  json.name card.column.name
end

json.board do
  json.id card.board.id
  json.name card.board.name
end

json.url board_card_url(card.board, card, format: :json)

# Usage in index
# app/views/cards/index.json.jbuilder
json.array! @cards do |card|
  json.partial! "cards/card", card: card
end

# Usage in show
# app/views/cards/show.json.jbuilder
json.partial! "cards/card", card: @card

json.comments @card.comments.order(created_at: :desc) do |comment|
  json.partial! "comments/comment", comment: comment
end

# Array with partials shorthand
json.cards @board.cards, partial: "cards/card", as: :card
```

## Conditional Attributes

```ruby
# Only for admins
if Current.user.admin?
  json.internal_notes @board.internal_notes
end

# Only when present
json.archived_at @board.archived_at if @board.archived?

# Merge another hash
json.merge! @board.metadata
```

## Caching in Jbuilder

```ruby
# Cache a single object
json.cache! @board do
  json.extract! @board, :id, :name, :description
end

# Cache a collection
json.boards do
  json.array! @boards, cache: true do |board|
    json.extract! board, :id, :name
  end
end
```

## Nested Resources

```ruby
# app/views/cards/index.json.jbuilder
json.board do
  json.id @board.id
  json.name @board.name
  json.url board_url(@board, format: :json)
end

json.cards @cards do |card|
  json.id card.id
  json.title card.title
  json.description card.description

  json.column do
    json.id card.column.id
    json.name card.column.name
  end

  json.creator do
    json.id card.creator.id
    json.name card.creator.name
  end

  json.comments_count card.comments.size
  json.url board_card_url(@board, card, format: :json)
end
```

## Pagination in Jbuilder

```ruby
json.boards @boards do |board|
  json.extract! board, :id, :name, :description, :created_at
  json.url board_url(board, format: :json)
end

json.pagination do
  json.current_page @boards.current_page
  json.per_page @boards.limit_value
  json.total_pages @boards.total_pages
  json.total_count @boards.total_count

  if @boards.next_page
    json.next_page boards_url(page: @boards.next_page, format: :json)
  end

  if @boards.prev_page
    json.prev_page boards_url(page: @boards.prev_page, format: :json)
  end
end
```

## Cursor-Based Pagination

```ruby
json.boards @boards do |board|
  json.extract! board, :id, :name, :created_at
end

json.pagination do
  if @boards.any?
    json.since @boards.first.created_at.iso8601
    json.before @boards.last.created_at.iso8601
    json.next_url boards_url(
      before: @boards.last.created_at.iso8601,
      limit: params[:limit],
      format: :json
    )
  end
end
```
