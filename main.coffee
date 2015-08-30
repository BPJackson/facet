@Tags = new Meteor.Collection 'tags'
@Items = new Meteor.Collection 'items'

Meteor.methods
      downvote: (itemId)->
          Items.update itemId,
              $addToSet: downvoters: Meteor.userId()
              $inc: downvotes: 1, points: -1
      upvote: (itemId)->
          Items.update itemId,
              $addToSet: upvoters: Meteor.userId()
              $inc: points: 1, upvotes: 1



Items.before.insert (userId, doc) ->
    doc.timestamp = Date.now()
    doc.owner = Meteor.userId()
    doc.upvotes = 0
    doc.upvoters = []
    doc.downvotes = 0
    doc.downvoters = []
    doc.points = 0

if Meteor.isClient
    Session.setDefault 'editing', null
    filter = new ReactiveArray []

    Accounts.ui.config
        passwordSignupFields: 'USERNAME_ONLY'
    Tracker.autorun -> Meteor.subscribe 'items', filter.array()
    Tracker.autorun -> Meteor.subscribe 'tags', filter.array()
    Meteor.subscribe 'users'


    uid = if Meteor.userId() then Meteor.userId()

    Template.home.events
        'click .add': ->
            newId = Items.insert {}
            Session.set 'editing', newId
        'click .filterTag': -> filter.push @name.toString()
        'click .unfilterTag': -> filter.remove @toString()

    Template.home.helpers
        globalTags: ->
            itemCount = Items.find().count()
            Tags.find {count: $lt: itemCount}, limit: 10
        filterlist: -> filter.list()
        items: -> Items.find {}, sort: timestamp: -1

    Template.item.helpers
        isEditing: -> Session.equals 'editing', @_id
        isOwner: -> @owner is uid
        canDownvote: -> uid
        canUpvote: -> uid
        canEdit: -> uid is @owner
        canClone: -> uid
        when: -> moment.utc(@timestamp).fromNow()
        username: ->
            owner = Meteor.users.findOne @owner
            if owner then owner.username

    Template.item.events
        'click .itemtag': (e)-> filter.push e.target.textContent
        'click .edit': (e,t)->
            $('.viewarea').dimmer('show')
            Session.set 'editing', @_id
        'click .save': (e,t)->
            val = t.find('textarea').value
            Items.update @_id, $set: body: val
            $('.viewarea').dimmer('hide')
            Session.set 'editing', null
        'click .clone': (e)->
            $('.viewarea').dimmer('show')
            cloneId = Items.insert {
                tags: @tags
                body: @body
                }
            Session.set 'editing', cloneId
        'click .upvote': -> Meteor.call 'upvote', @_id
        'click .downvote': -> Meteor.call 'downvote', @_id
        'click .delete': ->
            $('.viewarea').dimmer('hide')
            Items.remove @_id
    Template.editing.events
        'keyup input, keyup textarea':(e,t)->
            if (event.keyCode is 10 or event.keyCode is 13) and event.ctrlKey
                val = t.find('textarea').value
                Items.update @_id, $set: body: val
                $('.viewarea').dimmer('hide')
                Session.set 'editing', null

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

    Meteor.publish 'users', ->
        Meteor.users.find()

    Meteor.publish 'items', (filter)->
        match = {}
        if filter.length > 0 then match.tags= $all: filter
        Items.find match, limit: 10

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
