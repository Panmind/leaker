Leaker: The Best Way to Break MVC
=================================

Preface
-------

Hide from your software engineering teacher (and from DHH as well)
while you're reading this documentation.

Why?
----

The reason this plugin was written was to make AR's `update_attributes`
to work seamlessly with a tagging system built on CouchDB.

The tags were saved with references to the `User` who created them, but
unless we were using `accepts_nested_attributes_for`, there were no way
to pass the `current_user` without adding an extra parameter.

So, because we were in an hacky mood, we implemented this plugin.. that
shouldn't be used at all, but it's here because does interesting things
extending Rails behaviours

Usage
-----

You can leak any controller method to your models, via this simple DSL:

    class FooController < ApplicationController
      leaks :some_method, :to => [SomeModel]
    end

E.g., if you want to let the `Tagging` model know who the `current_user`
is, but only when invoking a `PostsController` method you could write:

    class PostsController < ApplicationController
      leaks :current_user, :to => [Tagging]
    end

Or, if you really want to make the Cheerleader die, you could even write

    class ApplicationController < ActionController::Base
      leaks :current_user, :to => :all
    end

And ALL `ActiveRecord::Base` instances and `CouchRest::ExtendedDocument`
instances will have a `current_user` method available.


Installation
------------

Beyond the scope of this document. You're breaking MVC, you should know
how to install this evil code yourself.

Gems? No way!

Afterthoughts
-------------

You should really not use this code :-) You've been warned!
