# Locale File Examples

## Models

```yaml
# config/locales/models/en.yml
en:
  activerecord:
    models:
      event: Event
      event_vendor: Event Vendor
    attributes:
      event:
        name: Name
        event_date: Event Date
        status: Status
        budget_cents: Budget
      event/statuses:
        draft: Draft
        confirmed: Confirmed
        cancelled: Cancelled
    errors:
      models:
        event:
          attributes:
            name:
              blank: "can't be blank"
              too_long: "is too long (maximum %{count} characters)"
            event_date:
              in_past: "can't be in the past"
```

```yaml
# config/locales/models/fr.yml
fr:
  activerecord:
    models:
      event: Événement
      event_vendor: Prestataire
    attributes:
      event:
        name: Nom
        event_date: Date de l'événement
        status: Statut
        budget_cents: Budget
      event/statuses:
        draft: Brouillon
        confirmed: Confirmé
        cancelled: Annulé
    errors:
      models:
        event:
          attributes:
            name:
              blank: "ne peut pas être vide"
              too_long: "est trop long (maximum %{count} caractères)"
```

## Views

```yaml
# config/locales/views/en.yml
en:
  events:
    index:
      title: Events
      new_event: New Event
      no_events: No events found
      filters:
        all: All
        upcoming: Upcoming
        past: Past
    show:
      edit: Edit
      delete: Delete
      confirm_delete: Are you sure?
    form:
      submit_create: Create Event
      submit_update: Update Event
    create:
      success: Event was successfully created.
    update:
      success: Event was successfully updated.
    destroy:
      success: Event was successfully deleted.
```

```yaml
# config/locales/views/fr.yml
fr:
  events:
    index:
      title: Événements
      new_event: Nouvel événement
      no_events: Aucun événement trouvé
      filters:
        all: Tous
        upcoming: À venir
        past: Passés
    show:
      edit: Modifier
      delete: Supprimer
      confirm_delete: Êtes-vous sûr ?
    form:
      submit_create: Créer l'événement
      submit_update: Mettre à jour
    create:
      success: L'événement a été créé avec succès.
```

## Shared/Common

```yaml
# config/locales/en.yml
en:
  common:
    actions:
      save: Save
      cancel: Cancel
      delete: Delete
      edit: Edit
      back: Back
      search: Search
      clear: Clear
    confirmations:
      delete: Are you sure you want to delete this?
    placeholders:
      search: Search...
      select: Select...
    messages:
      loading: Loading...
      no_results: No results found
      not_specified: Not specified
    date:
      formats:
        default: "%B %d, %Y"
        short: "%b %d"
        long: "%A, %B %d, %Y"
    time:
      formats:
        default: "%B %d, %Y %H:%M"
        short: "%b %d, %H:%M"
```

## Number/Currency Formatting (French)

```yaml
# config/locales/fr.yml
fr:
  number:
    currency:
      format:
        unit: "€"
        format: "%n %u"
        separator: ","
        delimiter: " "
        precision: 2
    format:
      separator: ","
      delimiter: " "
```

## Locale Names

```yaml
en:
  locales:
    en: English
    fr: Français
    de: Deutsch
```

## Components

```yaml
# config/locales/components/en.yml
en:
  components:
    event_card:
      status:
        draft: Draft
        confirmed: Confirmed
      days_until:
        zero: Today
        one: Tomorrow
        other: "In %{count} days"
```
