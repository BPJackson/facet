@Posts = new Meteor.Collection 'posts'
Posts.attachSchema new SimpleSchema
    tags:
        type: [String]
        autoform:
            type: "selectize"
            afFieldInput:
                multiple: true
                selectizeOptions:
                    plugins: ['remove_button']
                    create: (input) ->
                        {
                            value: input
                            text: input
                        }


@Tags = new Meteor.Collection 'tags'

Router.configure
    layoutTemplate: 'layout'

Router.route '/',
    name: 'root'
    template: 'posts'

if Meteor.isClient
    #AutoForm.addHooks 'add',
        #onSuccess: (formType, result) ->
            #Meteor.call 'updateTags'
            #AutoForm.resetForm add

    Meteor.subscribe 'posts'

    filter = new ReactiveArray ['Tom', 'Dick', 'Harry']

    Template.tags.onCreated ->
        arr = filter.array()
        Meteor.subscribe 'tags', arr
    Template.tags.onRendered ->

    Template.tags.helpers
        tags: -> Tags.find {}, sort: count: -1
        filter: -> filter.list()
    Template.tags.events
        'click .ftag': (event, template) -> filter.push @._id
        'click .button.icon': -> filter.remove @.toString()


    Template.posts.helpers
        posts: -> Posts.find()

    Meteor.startup ->
        AutoForm.setDefaultTemplate 'semanticUI'
        AutoForm.debug()



if Meteor.isServer
    Meteor.publish 'posts', -> Posts.find()
    Meteor.publish 'tags', (filterArray) ->
        sub = @
        initializing = true
        pipeline = [
            { $match: tags: $in: filterArray }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            #{ $sort: count: -1 }
            { $project: _id: 1, count: 1 }
            #{ $out: 'tags' }
        ]
        # Track any changes on the collection we are going to use for aggregation
        #query = Posts.find tags: $in: filterArray
        query = Posts.find()
        handle = query.observeChanges(
            added: (id) ->
                # observeChanges only returns after the initial `added` callbacks
                # have run. Until then, we don't want to send a lot of
                # `self.changed()` messages - hence tracking the
                # `initializing` state.
                if !initializing then runAggregation 'changed'
            removed: (id) -> runAggregation 'changed'
            changed: (id) -> runAggregation 'changed'
            error: (err) -> throw new (Meteor.Error)('Something went wrong:', err.message)

        )
        # Instead, we'll send one `self.added()` message right after
        # observeChanges has returned, and mark the subscription as
        # ready.
        # Wrap the aggregation call inside of a function
        # since it will be called more than once

        runAggregation = (action) ->
            Posts.aggregate(pipeline).forEach (e) ->
                if action == 'changed'
                    # Aggregate and update our collection with the new data changes
                    sub.changed 'tags', e._id,
                        _id: e._id
                        count: e.count
                else
                    # Aggregate and then add a new record to our collection
                    sub.added 'tags', e._id,
                        _id: e._id
                        count: e.count
                # Mark the subscription ready
                sub.ready()

        initializing = false
        # Run the aggregation initially to add some data to our aggregation collection
        runAggregation 'added'
        # Stop observing the cursor when client unsubs.
        # Stopping a subscription automatically takes
        # care of sending the client any removed messages.
        sub.onStop -> handle.stop()

    #Kadira.connect 'rFvGdJvAfypbQj3uP', '998ed03e-6c4d-4e65-a529-cb9f094bb97f'
    Posts.allow
        insert: -> true
    Meteor.methods
        updateTags: ->

    Meteor.startup ->
