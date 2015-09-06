@Tags = new Meteor.Collection 'tags'
@Items = new Meteor.Collection 'items'

Items.helpers
    author: -> Meteor.users.findOne @authorId

Meteor.methods
    vote: (itemId)->
        item = Items.findOne itemId
        me = Meteor.userId()
        
        if item.voters.indexOf(me) > -1
            Items.update itemId, $inc: {votes: -1}, $pull: voters: me
            Meteor.users.update item.authorId, $inc: points: -1
            return
        else
            Items.update itemId, $inc: {votes: 1}, $addToSet: voters: me
            Meteor.users.update item.authorId, $inc: points: 1
            return

if Meteor.isClient
    Session.setDefault 'editing', null
    Session.setDefault 'adding', null
    selectedTags = new ReactiveArray []
    selectedAuthor = new ReactiveArray []


    Accounts.ui.config 
        dropdownClasses: 'simple'
        passwordSignupFields: 'USERNAME_ONLY'
    Tracker.autorun -> Meteor.subscribe 'tags', selectedTags.array(), selectedAuthor.array()
    Tracker.autorun -> Meteor.subscribe 'items', selectedTags.array(), selectedAuthor.array(), Session.get 'adding'

    Meteor.subscribe 'users'
    
    Template.home.helpers
        globalTags: -> Tags.find {}

        selectedTags: -> selectedTags.list()
        
        selectedAuthor: -> selectedAuthor.list()

        items: -> Items.find {}, sort: {timestamp: -1}, limit: 1

        user: -> Meteor.user()
        
    Template.home.events
        'click .home': -> 
            selectedTags.clear()
            selectedAuthor.clear()
            Session.set 'adding', null
            Session.set 'editing', null
        'click .add': ->
            if Session.get 'adding' then return
            else 
                #selectedTags.clear()
                #selectedAuthor.clear()
                
                newId = Items.insert {
                    timestamp: Date.now()
                    authorId: Meteor.userId()
                    voters: []
                    votes: 0
                    }
                
                Session.set 'adding', newId
                Session.set 'editing', newId
            
        'click .selectTag': -> selectedTags.push @name.toString()
        'click .unselectTag': -> selectedTags.remove @toString()
        'click .unselectAuthor': -> selectedAuthor.remove @toString()
        
    Template.item.helpers
        isEditing: -> Session.equals 'editing', @_id

        isAuthor: -> @authorId is Meteor.userId()

        canEdit: -> Meteor.userId() is @authorId

        authorPoints: ->
            author = Meteor.users.findOne @authorId
            if author then author.points

        voteIconClass: -> if @voters.indexOf(Meteor.userId()) > -1 then 'thumbs up' else 'thumbs up outline'

        voteButtonClass: -> if not Meteor.userId() or @authorId is Meteor.userId() then 'disabled' else ''

    Template.item.events
        'click .edit': (e,t)-> Session.set 'editing', @_id

        'click .save': (e,t)->
            val = t.find('textarea').value
            Items.update @_id, $set: body: val

            item = Items.findOne @_id
            if Session.get 'adding' then item.tags.forEach (tag)-> selectedTags.push tag

            Session.set 'editing', null
            Session.set 'adding', null

        'click .username': (e)->
            selectedTags.clear()
            selectedAuthor.push @author().username

        'click .vote': -> Meteor.call 'vote', @_id

        'click .delete': ->
            Items.remove @_id
            selectedTags.clear()
            Session.set 'adding', null
            Session.set 'editing', null

    Template.editing.onRendered ->
        self = @
        @$('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'add tags'
            onAdd: (addedValue) -> Items.update self.data._id, $addToSet: tags: addedValue
            onRemove: (removedValue) ->
                selectedTags.remove removedValue.toString()
                Items.update self.data._id, $pull: tags: removedValue

if Meteor.isServer
    Accounts.onCreateUser (options, user) ->
        user.points = 0
        user.cloud = []
        user

    Items.allow
        insert: (userId, doc)-> doc.authorId is userId
        update: (userId, doc)-> true
        remove: (userId, doc)-> doc.authorId is userId
 
    Meteor.users.allow
        insert: (userId, doc)-> true
        update: (userId, doc)-> userId
        remove: (userId, doc)-> false


    Meteor.publish 'users', -> Meteor.users.find {}, 
        fields: 
            username:1
            points: 1

    Meteor.publish 'items', (selectedTags, selectedAuthor, adding)->
        match = {}

        if adding? then return Items.find adding

        if selectedTags.length > 0 then match.tags= $all: selectedTags else return null
        if selectedAuthor.length > 0
            author = Meteor.users.findOne username: selectedAuthor[0]
            match.authorId= author._id
        return Items.find match, limit: 1

    Meteor.publish 'tags', (selectedTags, selectedAuthor)->
        self = @
        match = {}

        if selectedTags.length > 0 then match.tags= $all: selectedTags

        if selectedAuthor.length > 0
            author = Meteor.users.findOne username: selectedAuthor[0]
            match.authorId= author._id


        cloud = Items.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: selectedTags }
            { $sort: count: -1 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]


        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()
