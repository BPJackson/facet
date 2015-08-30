@Tags = new Meteor.Collection 'tags'
@Items = new Meteor.Collection 'items'

Meteor.methods
    clickUpvote: (itemId)->

        item = Items.findOne itemId
        uid = Meteor.userId()

        #toggle if downvoted
        if item.downvoters.indexOf(uid) > -1
            Items.update itemId,
                $pull: downvoters: uid
                $addToSet: upvoters: uid
                $inc: downvotes: -1, points: 2, upvotes: 1

        #undo if upvoted
        else if item.upvoters.indexOf(uid) > -1
            Items.update itemId,
                $pull: upvoters: uid
                $inc: upvotes: -1, points: -1

        else
            Items.update itemId,
                $inc: points: 1, upvotes: 1
                $addToSet: upvoters: uid

    clickDownvote: (itemId)->

        item = Items.findOne itemId
        uid = Meteor.userId()

        #toggle if upvoted
        if item.upvoters.indexOf(uid) > -1
            Items.update itemId,
                $pull: upvoters: uid
                $addToSet: downvoters: uid
                $inc: upvotes: -1, points: -2, downvotes: 1

        #undo if downvoted
        else if item.downvoters.indexOf(uid) > -1
            Items.update itemId,
                $pull: downvoters: uid
                $inc: downvotes: -1, points: 1

        else
            Items.update itemId,
                $inc: points: -1, downvotes: 1
                $addToSet: downvoters: uid

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
        isOwner: -> @owner is Meteor.userId()

        canDownvote: -> Meteor.userId()
        canUpvote: -> Meteor.userId()

        canEdit: -> Meteor.userId()  is @owner
        canClone: -> Meteor.userId()

        when: -> moment.utc(@timestamp).fromNow()
        username: ->
            owner = Meteor.users.findOne @owner
            if owner then owner.username

        upvoteButtonClass: -> if not Meteor.userId() or @owner is Meteor.userId() then 'disabled' else ''
        downvoteButtonClass: -> if not Meteor.userId() or @owner is Meteor.userId() then 'disabled' else ''

        upvoteIconClass: -> if @upvoters.indexOf(Meteor.userId()) > -1 then 'thumbs up' else 'thumbs up outline'
        downvoteIconClass: -> if @downvoters.indexOf(Meteor.userId()) > -1 then 'thumbs down' else 'thumbs down outline'


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

        'click .upvote': -> Meteor.call 'clickUpvote', @_id
        'click .downvote': -> Meteor.call 'clickDownvote', @_id

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
