@Tags = new Meteor.Collection 'tags'
@Docs = new Meteor.Collection 'docs'

if Meteor.isClient
    Session.setDefault 'editing', null
    
    selected = new ReactiveArray []

    Accounts.ui.config 
        passwordSignupFields: 'USERNAME_ONLY'
        dropdownClasses: 'simple'
        
    Tracker.autorun -> Meteor.subscribe 'tags', selected.array()
    Tracker.autorun -> Meteor.subscribe 'docs', selected.array(), Session.get 'editing'

    Template.cloud.helpers
        selected: -> selected.list()
        tags: -> 
            docCount = Docs.find().count()
            if docCount > 0 then Tags.find {count: $lt: docCount} else Tags.find()
        docs: -> Docs.find {}

        
    Template.doc.helpers
        isEditing: -> Session.equals 'editing', @_id
        postButtonClass: -> if selected.array().indexOf(@valueOf()) > -1 then 'active' else ''

        canEdit: -> Meteor.userId() is @authorId

    Template.menu.events
        'click .home': -> 
            selected.clear()
            Session.set 'editing', null
        
        'click .add': ->
            newId = Docs.insert {
                timestamp: Date.now()
                authorId: Meteor.userId()
                }
            Session.set 'editing', newId
            selected.clear()
            
    Template.cloud.events
        'click .select': -> selected.push @name.toString()
        
        'click .unselect': -> selected.remove @toString()
    
    Template.doc.events
        'click .edit': (e,t)-> Session.set 'editing', @_id
        'click .postTag': (e)->
            Session.set 'editing', null
            if selected.array().indexOf(@toString()) is -1 then selected.push @toString()
            else selected.remove @toString()

        'click .clone': (e)->
            cloneId = Docs.insert {
                tags: @tags
                body: @body
                authorId: Meteor.userId()
                }
            Session.set 'editing', cloneId
        
        'click .save': (e,t)->
            val = t.find('textarea').value
            Docs.update @_id, $set: body: val
            selected.clear()
            @tags.forEach (tag)-> selected.push tag
            Session.set 'editing', null

        'click .delete': ->
            Docs.remove @_id
            selected.clear()
            Session.set 'editing', null
            
    Template.editing.onRendered ->
        $ ->
            $('#edit').editable 
                inlineMode: false
                minHeight: 100
                toolbarFixed: false
                #buttons: [
                    #'bold'
                    #'italic'
                    #'sep'
                    #'indent'
                    #'outdent'
                    #'insertOrderedList'
                    #'insertUnorderedList'
                    #'sep'
                    #'createLink'
                    #'fullscreen'
                    #]
           return

if Meteor.isServer
    Docs.allow
        insert: (userId, doc)-> doc.authorId is userId
        update: (userId, doc)-> doc.authorId is userId
        remove: (userId, doc)-> doc.authorId is userId
 
    Meteor.publish 'docs', (selected, editing)->
        if editing? then return Docs.find editing
        match = {}
        if selected.length > 0 then match.tags= $all: selected else return null
        return Docs.find match

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
            { $sort: count: -1, _id: 1 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]

        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()
