# GitHub Platform – Logical Data Model (Crow’s Foot Notation)

## Purpose of This Document

This document defines the logical data model derived from the conceptual
ER model of the GitHub platform.

It describes:

- Tables
- Primary keys
- Foreign keys
- Relationship cardinalities

This model is implementation-oriented but DBMS-agnostic.
No SQL data types are defined here.

---

## Translation Rules Applied

- Each conceptual entity becomes a table
- Each attribute becomes a column
- Key attributes become primary keys
- One-to-many relationships are implemented using foreign keys
- Many-to-many relationships are resolved using associative tables

---

## Table Definitions

### User

Represents a GitHub user.

**Primary Key**

- user_id

**Columns**

- user_id
- username
- email
- created_at
- bio
- location

---

### Organization

Represents a GitHub organization.

**Primary Key**

- org_id

**Columns**

- org_id
- name
- description
- created_at

---

### Repository

Represents a code repository.

**Primary Key**

- repo_id

**Foreign Keys**

- owner_user_id → User.user_id (nullable)
- owner_org_id → Organization.org_id (nullable)

**Columns**

- repo_id
- name
- description
- visibility
- created_at
- owner_user_id
- owner_org_id

A Repository must be owned by exactly one entity
(either a User or an Organization).

---

### Commit

Represents a commit made to a repository.

**Primary Key**

- commit_id

**Foreign Keys**

- repo_id → Repository.repo_id
- author_user_id → User.user_id

**Columns**

- commit_id
- commit_hash
- message
- committed_at
- repo_id
- author_user_id

---

### Issue

Represents an issue created in a repository.

**Primary Key**

- issue_id

**Foreign Keys**

- repo_id → Repository.repo_id
- author_user_id → User.user_id

**Columns**

- issue_id
- title
- description
- status
- created_at
- repo_id
- author_user_id

---

### PullRequest

Represents a pull request made to a repository.

**Primary Key**

- pr_id

**Foreign Keys**

- repo_id → Repository.repo_id
- author_user_id → User.user_id

**Columns**

- pr_id
- title
- status
- created_at
- merged_at
- repo_id
- author_user_id

---

### Star (Associative Table)

Represents the many-to-many relationship between User and Repository.

**Composite Primary Key**

- user_id
- repo_id

**Foreign Keys**

- user_id → User.user_id
- repo_id → Repository.repo_id

**Columns**

- user_id
- repo_id
- starred_at

---

## Relationship Summary

- User 1 —— N Repository (ownership)
- Organization 1 —— N Repository (ownership)
- Repository 1 —— N Commit
- User 1 —— N Commit
- Repository 1 —— N Issue
- User 1 —— N Issue
- Repository 1 —— N PullRequest
- User 1 —— N PullRequest
- User N —— M Repository (via Star)

---

## Diagram Reference

The logical data model diagram using Crow’s Foot notation
is provided in:

`diagrams/logical/github-logical.png`
