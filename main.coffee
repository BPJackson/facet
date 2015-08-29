@Tags = new Meteor.Collection 'tags'
@Items = new Meteor.Collection 'items'

if Meteor.isClient
    Session.setDefault 'editing', null
    filter = new ReactiveArray []

    Accounts.ui.config
        passwordSignupFields: 'USERNAME_ONLY'

    Tracker.autorun -> Meteor.subscribe 'items', filter.array()
    Tracker.autorun -> Meteor.subscribe 'tags', filter.array()



    Template.home.events
        'click .add': ->
            Items.insert {
                owner: Meteor.userId()
                timestamp: new Date()
                }
        'click .filterTag': -> filter.push @name.toString()
        'click .unfilterTag': -> filter.remove @toString()
    Template.home.helpers
        globalTags: ->
            itemCount = Items.find().count()
            Tags.find {count: $lt: itemCount}, limit: 10
        filterlist: -> filter.list()
        items: -> Items.find()

    Template.item.helpers


        isEditing: -> Session.equals 'editing', @_id
        isOwner: -> @owner is Meteor.userId()

        canDownvote: ->
        canUpvote: ->
        canEdit: -> Meteor.userId() is @owner
        canClone: -> Meteor.userId() is @owner

    Template.item.events
        'click .doctag': (e)-> filter.push e.target.textContent
        'click .edit': -> Session.set 'editing', @_id
        'click .editing': -> Session.set 'editing', null
        'click .clone': (e)->



    Template.editing.events
        'keyup #itembodyarea': _.throttle(((e,t) ->
            val = e.target.value
            Items.update @_id, $set: body: val
            ), 1000)
    Template.editing.onRendered ->
        self = @
        @$('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'add tags'
            onAdd: (addedValue) ->
                if addedValue is 'delete this' then Items.remove self.data._id
                else Items.update self.data._id, $addToSet: tags: addedValue
            onRemove: (removedValue) -> Items.update self.data._id, $pull: tags: removedValue

if Meteor.isServer

    Items.allow
        insert: (userId, doc)-> doc.owner is userId
        update: (userId, doc)-> doc.owner is userId
        remove: (userId, doc)-> doc.owner is userId
        fetch: [ 'owner' ]


    Meteor.publish 'items', (filter)->
        match = {}
        if filter.length > 0 then match.tags= $all: filter
        Items.find match

    Meteor.publish 'tags', (filter)->
        me = @
        match = {}
        if filter.length > 0 then match.tags= $all: filter
        cloud = Items.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: filter }
            { $sort: count: -1 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]
        cloud.forEach (tag) -> me.added 'tags', Random.id(), { name: tag.name, count:tag.count }
        me.ready()
