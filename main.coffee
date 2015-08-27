@Tags = new Meteor.Collection 'tags'
@Docs = new Meteor.Collection 'docs'

if Meteor.isClient
    Session.setDefault 'editing', null
    filter = new ReactiveArray []
    Tracker.autorun -> Meteor.subscribe 'docs', filter.array()
    Tracker.autorun -> Meteor.subscribe 'tags', filter.array()

    Accounts.ui.config
        passwordSignupFields: 'USERNAME_ONLY'


    Template.home.helpers
        docs: -> Docs.find()
        gtags: -> Tags.find {}, sort: count: -1
        filterlist: -> filter.list()
    Template.home.events
        'click .filterTag': -> filter.push @name.toString()
        'click .unfilterTag': -> filter.remove @toString()


    Template.doc.helpers
        editing:  -> Session.equals 'editing', @_id

    Template.doc.events
        'click .edit': -> Session.set 'editing', @_id
        'click .stopEditing': -> Session.set 'editing', null

    Template.edit.helpers
        doctags:-> @tags
    Template.edit.events
        'click .delete': -> Docs.remove @_id

        'click .load': (e,t) ->
            #val2 = t.$('#tagselector').dropdown('set value', 'gopher')
            t.$('#tagselector').dropdown('set exactly', @tags)
        'click .save': (e,t) ->
            val = t.$('#tagselector').dropdown('get text')
            console.log val
    Template.edit.onRendered ->
        self = @
        @$('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'add tags'
            onAdd: (addedValue) -> Docs.update self.data._id, $addToSet: tags: addedValue
            onRemove: (removedValue) -> Docs.update self.data._id, $pull: tags: removedValue
    Template.menu.events
        'click .add': -> Docs.insert {}


if Meteor.isServer
    Docs.allow
        insert: -> true
        update: -> true
        remove: -> true
    Meteor.publish 'docs', (filter) ->
        match = {}
        if filter.length > 0 then match.tags= $all: filter
        #Docs.find match, limit: 1
        Docs.find match

    Meteor.publish 'tags', (filter) ->
        me = @
        match = {}
        if filter.length > 0 then match.tags= $all: filter
        cloud = Docs.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: filter }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]
        cloud.forEach (tag) -> me.added 'tags', Random.id(), { name: tag.name, count:tag.count }
        me.ready()
