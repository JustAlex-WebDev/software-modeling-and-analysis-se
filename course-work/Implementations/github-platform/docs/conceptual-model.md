# GitHub Platform – Conceptual ER Model

## Purpose of This Document

This document provides a precise textual specification of the conceptual
Entity-Relationship (ER) model for the GitHub platform.

It exists to:

- Clearly define the entities, attributes, and relationships
- Act as a source of truth for diagrams created in Figma
- Help tools such as GitHub Copilot understand the domain model
- Ensure correct translation to the logical and physical database models

This model represents the **conceptual design**, not the implementation.
No SQL, data types, or foreign keys are defined here.

---

## Modeled Platform Scope

The modeled platform is **GitHub**, a collaborative software development platform.

The conceptual model focuses on:

- Users and organizations
- Code repositories
- Commits and contributions
- Issues and pull requests
- User interactions such as starring repositories

The model does NOT include:

- CI/CD pipelines
- Billing or subscriptions
- Permissions or roles
- GitHub Actions or workflows

---

## Entity Definitions

### 1. User (Strong Entity)

Represents a registered GitHub user account.

**Key Attribute**

- user_id (Primary Key)

**Attributes**

- user_id
- username
- email
- created_at
- bio
- location

A User can:

- Own repositories
- Author commits
- Create issues
- Create pull requests
- Star repositories

---

### 2. Organization (Strong Entity)

Represents a GitHub organization that can own repositories.

**Key Attribute**

- org_id (Primary Key)

**Attributes**

- org_id
- name
- description
- created_at

An Organization can:

- Own multiple repositories

---

### 3. Repository (Strong Entity)

Represents a GitHub code repository.

**Key Attribute**

- repo_id (Primary Key)

**Attributes**

- repo_id
- name
- description
- visibility
- created_at

A Repository:

- Is owned by either a User or an Organization
- Contains commits
- Contains issues
- Contains pull requests
- Can be starred by users

---

### 4. Commit (Strong Entity)

Represents a commit made to a repository.

**Key Attribute**

- commit_id (Primary Key)

**Attributes**

- commit_id
- commit_hash
- message
- committed_at

A Commit:

- Belongs to exactly one Repository
- Is authored by exactly one User
- Cannot exist without a Repository (total participation)

---

### 5. Issue (Strong Entity)

Represents an issue created in a repository.

**Key Attribute**

- issue_id (Primary Key)

**Attributes**

- issue_id
- title
- description
- status
- created_at

An Issue:

- Belongs to exactly one Repository
- Is created by exactly one User

---

### 6. PullRequest (Strong Entity)

Represents a pull request proposing changes to a repository.

**Key Attribute**

- pr_id (Primary Key)

**Attributes**

- pr_id
- title
- status
- created_at
- merged_at

A Pull Request:

- Belongs to exactly one Repository
- Is created by exactly one User

---

### 7. Star (Associative Entity)

Represents the action of a user starring a repository.

**Attributes**

- starred_at

The Star entity conceptually resolves a many-to-many relationship
between User and Repository.

---

## Relationship Definitions

### User — owns — Repository

- Relationship Type: Binary
- Cardinality: One-to-Many (1:N)
- A User can own many Repositories
- A Repository is owned by exactly one User (if not owned by an Organization)
- Participation: Partial on Repository side

---

### Organization — owns — Repository

- Relationship Type: Binary
- Cardinality: One-to-Many (1:N)
- An Organization can own many Repositories
- A Repository may or may not be owned by an Organization
- Participation: Partial on Repository side

---

### Repository — contains — Commit

- Relationship Type: Binary
- Cardinality: One-to-Many (1:N)
- A Repository contains many Commits
- A Commit belongs to exactly one Repository
- Participation: Total on Commit side

---

### User — authors — Commit

- Relationship Type: Binary
- Cardinality: One-to-Many (1:N)
- A User can author many Commits
- A Commit is authored by exactly one User

---

### Repository — has — Issue

- Relationship Type: Binary
- Cardinality: One-to-Many (1:N)
- A Repository can have many Issues
- An Issue belongs to exactly one Repository

---

### User — creates — Issue

- Relationship Type: Binary
- Cardinality: One-to-Many (1:N)
- A User can create many Issues
- An Issue is created by exactly one User

---

### Repository — has — PullRequest

- Relationship Type: Binary
- Cardinality: One-to-Many (1:N)
- A Repository can have many Pull Requests
- A Pull Request belongs to exactly one Repository

---

### User — creates — PullRequest

- Relationship Type: Binary
- Cardinality: One-to-Many (1:N)
- A User can create many Pull Requests
- A Pull Request is created by exactly one User

---

### User — stars — Repository

- Relationship Type: Binary
- Cardinality: Many-to-Many (M:N)
- A User can star many Repositories
- A Repository can be starred by many Users
- This relationship is conceptually resolved via the Star entity

---

## Notes on ER Modeling Decisions

- All entities are modeled as strong entities
- The Star entity is modeled as an associative entity
- No weak entities are used in this model
- Attributes are atomic (no composite attributes are modeled)
- Derived attributes are intentionally excluded at the conceptual level

---

## Diagram Reference

The conceptual ER diagram corresponding to this specification
is provided as a Chen notation diagram in:

`diagrams/conceptual/github-conceptual.png`
