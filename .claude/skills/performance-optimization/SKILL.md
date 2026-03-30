---
name: performance-optimization
description: >-
  Identifies and fixes Rails performance issues including N+1 queries, slow
  queries, and memory problems. Use when optimizing queries, fixing N+1 issues,
  improving response times, or when user mentions performance, slow,
  optimization, or Bullet gem. WHEN NOT: Caching-specific patterns (use
  caching-strategies), adding new features, or general code quality
  improvements unrelated to speed.
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob, Bash
---

# Performance Optimization for Rails 8

## Overview

Performance optimization focuses on:
- N+1 query detection and prevention
- Query optimization
- Memory management
- Response time improvements
- Database indexing

## Quick Start

```ruby
# Gemfile
group :development, :test do
  gem 'bullet'           # N+1 detection
  gem 'rack-mini-profiler' # Request profiling
  gem 'memory_profiler'  # Memory analysis
end
```

## N+1 Query Detection and Prevention

N+1 queries occur when code loads a collection then makes a separate query for each associated record. The Bullet gem detects these automatically. Fix them with eager loading via `includes`, `preload`, or `eager_load`.

### Eager Loading Decision Table

| Method | Use When |
|--------|----------|
| `includes` | Most cases (Rails chooses best strategy) |
| `preload` | Forcing separate queries, large datasets |
| `eager_load` | Filtering on association, need single query |
| `joins` | Only need to filter, don't need association data |

Key patterns: Bullet configuration, eager loading methods, scoped eager loading, counter caches, N+1 specs with query count assertions.

See [references/n-plus-one.md](references/n-plus-one.md) for all code examples and patterns.

## Query Optimization

Optimize queries by selecting only needed columns, using batch processing for large datasets, and choosing efficient existence checks.

### Key Patterns

| Pattern | Bad | Good |
|---------|-----|------|
| Column selection | `User.all.map(&:name)` | `User.pluck(:name)` |
| Large iterations | `Event.all.each { ... }` | `Event.find_each { ... }` |
| Existence checks | `.any?` / `.present?` | `.exists?` |
| Collection size | `.length` (loads all) | `.size` (smart) |

### Database Indexing

Add indexes for: foreign keys, columns in WHERE/ORDER BY/JOIN clauses, and unique constraints. Use composite indexes for multi-column queries. Use partial indexes for filtered subsets.

### Query Analysis

Use `Event.where(...).explain(:analyze)` to inspect query plans. Set up slow query logging via `ActiveSupport::Notifications` to catch queries over a threshold.

See [references/query-optimization.md](references/query-optimization.md) for all code examples and patterns.

## Memory Management and Profiling

Use `memory_profiler` to detect memory issues. Prefer `pluck` over loading full AR objects, use `find_each` for streaming, and use `update_all` / `in_batches` for bulk operations.

### Rack Mini Profiler

Provides per-request profiling in development. Shows query count, timing, and flamegraphs (with `stackprof` gem). Access via the profiler badge or `?pp=flamegraph`.

See [references/memory-and-profiling.md](references/memory-and-profiling.md) for all code examples and patterns.

## Quick Fixes Reference

| Problem | Solution |
|---------|----------|
| N+1 on belongs_to | `includes(:association)` |
| N+1 on has_many | `includes(:association)` |
| Slow COUNT | Add counter_cache |
| Loading all columns | Use `select` or `pluck` |
| Large dataset iteration | Use `find_each` |
| Missing index on FK | Add index on `*_id` columns |
| Slow WHERE clause | Add index on filtered column |
| Loading unused associations | Remove from `includes` |

## Performance Checklist

- [ ] Bullet enabled in development/test
- [ ] No N+1 queries in critical paths
- [ ] Foreign keys have indexes
- [ ] Counter caches for frequent counts
- [ ] Eager loading in controllers
- [ ] Batch processing for large datasets
- [ ] Query analysis for slow endpoints

## Workflow

1. **Detect** -- Enable Bullet, run specs, check Rack Mini Profiler
2. **Analyze** -- Use `explain(:analyze)`, check slow query logs, profile memory
3. **Fix** -- Apply the appropriate pattern from the reference files
4. **Verify** -- Re-run specs, confirm query counts, check profiler

## Reference Files

- [references/n-plus-one.md](references/n-plus-one.md) -- N+1 detection, eager loading methods, Bullet config, counter caches, testing patterns
- [references/query-optimization.md](references/query-optimization.md) -- Column selection, batch processing, indexing strategies, EXPLAIN analysis, slow query logging
- [references/memory-and-profiling.md](references/memory-and-profiling.md) -- Memory profiler usage, memory-efficient patterns, Rack Mini Profiler setup, deployment checklist
