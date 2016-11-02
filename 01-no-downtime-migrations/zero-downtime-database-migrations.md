Performing zero downtime database migrations
============================================

Étienne Lafarge
---------------

### Context

On a modern deployment of a given backend service, one would like to have that
service always available, even during deployments. Different rollout strategies
have been developped for that purpose (blue/green deployments, progressive
rollouts such as in Kubernetes...) and if you're reading this article, you
porbably already have something like that set up... **but**, you also know for
sure that there's an edge case that's not easy to handle: **deploying a database
migration without downtime**.

Indeed, deploying an application on a higly available cluster requires one
thing: **two different versions of your application must run at the same time**,
not just two different instances. As a matter of fact, running multiple
instances of one application implies one thing: you're storing your
application's **state** *outside* of the application itself, thereby outsourcing
the issue of sharding the state (or just not sharding it at all...)  to another
service, usually a database.

But what if you need to fundamentally alter that **state** so that the new
version of your application - call it `v2` - couldn't run alongside the old one
(`v1`) ? You'd need to shutdown `v1` before migrating and deploying `v2` which
means **downtime**.

However, this **deadlock can be avoided in most cases**. First of all, not all
migrations would trigger `v1` and `v2` to be incompatible, actually, *most*
migrations you perform probably are **backwards-compatible**, especially if
you followed good database design practices from scracth. Furthermore, in
the (hopefully rare) cases where you would have to perform a
backwards-incompatible migration it can almost always be peformed in a
backward-compatible way by splitting the backward-incompatible migrations in
several backward-compatible migrations.

### Avoiding backwards incompatible migrations

Let's take the simple example of renaming a field `a` to `b`. Running `v1`, that
requires the presence of field `a`, and `v2` that needs `b` is obviously
impossible. **Renaming a field is therefore a backward-incompatible migration**,
as well as changing its type (but not its description...).

As it appears, migrations aren't equal when it comes to backward-compatibility.
**adding a field** isn't though, and that's probably what you'll mostly do as
your application grows.

**Deleting a field** is backward incompatible but can be
split into two operations. First of all removing the field only in the code and
deploy the `app`. Then, probably during another deployment of the project as
part of your CI pipeline, delete the field in the database itself.

Using Django for instance, this would be fairly simple:
  * first, delete the field in your model (and everywhere else in the code),
    then deploy.
  * once the deployment is done, run `python manage.py makemigrations` to
    generate your migration files, commit them and deploy (drop the field)

As we can see, most common migration cases can be handled in a fairly easy way,
keeping backward-compatibility, and therefore high availability, all along the
process. Only the case of **updates** is trickier but can be avoided by choosing
good properties for fields from start. Even better, our widely-used ORMs are
usually tend towards doing that by themselves.

### What if want to run that field update ?

Updating as we said, is totally backwards-incompatible, but it's possible to
split it into three backward-compatible steps. As you'll see, it might not be as
obvious as it may feel in the first place.

For simplicity's sake, we'll take the example of renaming a field from `a` (used
by `v1`) to `b` (used by `v2`).

#### Step 1: Deploy a `v2.alpha` version that create `b` and writes in it

![no downtime database update step 1](./images/update_step_1.png "Deploying a `v2.alpha` version")

The `v2.alpha` commit includes both a migration and code changes:
 * a migration that create the `b` field
 * code that reads from `a` (`b` isn't populated yet), writes to `a` (`v1`
   requires that) and writes to `b` as well (we'll explain why in the next
   step).

#### Step 2: Copy all values from `a` to `b`

![no downtime database update step 2](./images/update_step_2.png "Copying all entities from `a` to `b`")

With `v2.alpha` writing to `b`, we can therefore be sure that `b` contains an
up-to-date version of all the data (which wouldn't have been the case if we
weren't already writing to `b` at the beginning of the copy: some elements could
have been changed in `a` after being copied to `b`).

#### Step 3: `b` is functional, let's also read from it (but don't drop `a`!)

![no downtime database update step 3](./images/update_step_3.png "Deploying the final `v2` code")

This deployment of `v2` reads and write from `b`, but it must not contain
the migration that deletes `a`, otherwise, all `v1.alpha` will stop working at
once, before `v2` actually started and some downtime will occur (see "worst
case migration deployment")

#### Step 4: Ok, no-one needs `a` anymore, let's delete the field !

![no downtime database update step 4](./images/update_step_4.png "Dropping field `a`, finally!")

And we finally released `v2` to prod !

In total, assuming a migration is "a commit of a migration file in your
project's version-control system", it boils down to 4 commits (one per step)
instead of one... so yeah, choose good names from start :)

Worst case migration deployment (if the CI & CD pipelines do their job)
-----------------------------------------------------------------------

If the CI pipeline does its jobs, a migration that makes `v2` fail will never be
deployed (Unit Tests and possibly Integration Tests will fail), so `v2` should
work (we can ensure it does or refuses to start with post-migration tests as
detailed below). When it hits the production environment (during CD) it runs
the migrations and breaks `v1`, but then starts, which hopefully shouldn't take
long (I hope you didn't create an index in that migration...). We've had at most
a few seconds of downtime.

At scale, this isn't that easy though: if you had 100 instances of `v1` running
and rolls out new instances one by one (like Kubernetes does by default), only
one instance of `v2` will be available when all `v1`s die... `v2` won't hold for
long and DevOps guys will have to force-deploy `v2` (or roll back the migrations
and have `v1`s work again).

But for a worst case scenario... it could be much worse :)

Collateral benefits
-------------------
 * At each start of the application, we can attempt to apply migrations if they
   exist, which means no migration logic has to be handled in the Continuous
   Deployment pipeline.
 * The moment after migrations have been run and before the backend really
   starts is a good moment to run some integration tests (such as creating an
   instance of a model and playing with it for every model in the app, which
   should be doable even without an ORM and see if exceptions are thrown). If
   these fail, it's easier to revert the migrations we just applied (we probably
   still have a record of what they were in that piece of code). Also if there
   are several migrations and one fails in the middle, it's a good place to roll
   them all back.
   At the CI/CD level we should stop the deployment (Kubernetes does this out of
   the box for instance, and any decent Continous Deployment pipeline should
   already have implemented some similar logic otherwise).
