@Tags = new Meteor.Collection 'tags'
@Docs = new Meteor.Collection 'docs'

if Meteor.isClient
    Session.setDefault 'editing', null
    filter = new ReactiveArray []
    Tracker.autorun -> Meteor.subscribe 'docs', filter.array()
    Tracker.autorun -> Meteor.subscribe 'tags', filter.array()

    Accounts.ui.config
        passwordSignupFields: 'USERNAME_ONLY'

    Template.menu.events
        'click .add': -> Docs.insert {}

    Template.home.helpers
        docs: -> Docs.find()
        globalTags: -> Tags.find {}, sort: count: -1
        filterlist: -> filter.list()
    Template.home.events
        'click .filterTag': -> filter.push @name.toString()
        'click .unfilterTag': -> filter.remove @toString()
        #'click .toggle': (e,t) -> t.$('.card').transition('scale')

    Template.home.onRendered ->
        #@$('.card').transition('scale')

    Template.doc.helpers
        editing: -> Session.equals 'editing', @_id

    Template.doc.events
        'click .edit': _.throttle(((e,t) ->
            #t.$('.editclass').transition('flip horizontal')
            Session.set('editing', @_id)
            ), 500)
        'click .save': -> Session.set 'editing', null
        'click .delete': -> Docs.remove @_id

    Template.edit.events
        'keyup #docbodyarea': (e,t) ->
            console.log e.target.value
            val = e.target.value
            Docs.update @_id, $set: body: val
    Template.edit.helpers
        docbody:-> @body
    Template.edit.onRendered ->
        self = @
        @$('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'add tags'
            onAdd: (addedValue) -> Docs.update self.data._id, $addToSet: tags: addedValue
            onRemove: (removedValue) -> Docs.update self.data._id, $pull: tags: removedValue


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
