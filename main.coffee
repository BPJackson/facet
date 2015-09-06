@Tags = new Meteor.Collection 'tags'
@Docs = new Meteor.Collection 'docs'

if Meteor.isClient
    Session.setDefault 'editing', null
    Session.setDefault 'adding', null
    selected = new ReactiveArray []

    Accounts.ui.config 
        dropdownClasses: 'simple'
        passwordSignupFields: 'USERNAME_ONLY'
    Tracker.autorun -> Meteor.subscribe 'tags', selected.array()
    Tracker.autorun -> Meteor.subscribe 'docs', selected.array(), Session.get 'adding'

    Template.facet.helpers

        selected: -> selected.list()

        tags: -> Tags.find {}
        
        docs: -> Docs.find {}, sort: {timestamp: -1}, limit: 1
        isEditing: -> Session.equals 'editing', @_id
        canEdit: -> Meteor.userId() is @authorId

    Template.facet.events
        'click .home': -> 
            selected.clear()
            Session.set 'adding', null
            Session.set 'editing', null
        'click .add': ->
            newId = Docs.insert {
                timestamp: Date.now()
                authorId: Meteor.userId()
                }
            
            Session.set 'adding', newId
            Session.set 'editing', newId
            
        'click .select': -> selected.push @name.toString()
        'click .unselect': -> selected.remove @toString()

        'click .edit': (e,t)-> Session.set 'editing', @_id
        'click .save': (e,t)->
            val = t.find('textarea').value
            Docs.update @_id, $set: body: val

            item = Docs.findOne @_id
            if Session.get 'adding' then item.tags.forEach (tag)-> selected.push tag

            Session.set 'editing', null
            Session.set 'adding', null

        'click .delete': ->
            docs.remove @_id
            selected.clear()
            Session.set 'adding', null
            Session.set 'editing', null

    Template.editing.onRendered ->
        self = @
        @$('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'add tags'
            onAdd: (addedValue) -> Docs.update self.data._id, $addToSet: tags: addedValue
            onRemove: (removedValue) ->
                selected.remove removedValue.toString()
                Docs.update self.data._id, $pull: tags: removedValue

if Meteor.isServer
    Docs.allow
        insert: (userId, doc)-> doc.authorId is userId
        update: (userId, doc)-> doc.authorId is userId
        remove: (userId, doc)-> doc.authorId is userId
 
    Meteor.publish 'docs', (selected, adding)->
        match = {}
        if adding? then return Docs.find adding
        if selected.length > 0 then match.tags= $all: selected else return null
        return Docs.find match, limit: 1

    Meteor.publish 'tags', (selected)->
        self = @
        match = {}

        if selected.length > 0 then match.tags= $all: selected

        cloud = Docs.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: selected }
            { $sort: count: -1 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]

        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()
