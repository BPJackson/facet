@Tags = new Meteor.Collection 'tags'
@Docs = new Meteor.Collection 'docs'
Docs.attachSchema new SimpleSchema
    tags:
        type: [String]
        autoform:
            type: "selectize"
            label: 'Add tags'
            placeholder: 'hit enter after each'
            afFieldInput:
                multiple: true
                selectizeOptions:
                    plugins: ['remove_button']
                    persist: false
                    create: (input) ->
                        {
                            value: input
                            text: input
                        }
    authorId:
        type: String
    authorName:
        type: String
    votes:
        type: Number
        defaultValue: 1
    voters:
        type: [String]
        defaultValue: []
    submitted:
        type: Date
        defaultValue: new Date()
Docs.after.insert (userId, doc) -> Meteor.call 'aggUser', userId

Router.configure
    layoutTemplate: 'layout'
Router.route '/',
    name: 'root'
    template: 'docs'
Router.route 'editor',
    name: 'editor'
    path: '/docs/:_id'
    template: 'editor'
    subscriptions: ->
        Meteor.subscribe 'document', @params._id
    onBeforeAction: ->
        Session.set 'currentRoute', 'editor'
        Session.set 'currentDocument', @params._id
        @next()

Meteor.methods
    removeDoc: (docId) -> Docs.remove docId
    vote: (docId) ->
        user = Meteor.user()
        Docs.update {
            _id: docId
            voters: $ne: user._id
        },
            $addToSet: voters: user._id
            $inc: votes: 1

        origin = Docs.findOne docId
        Docs.insert
            authorId: user._id
            authorName: user.profile.name
            tags: origin.tags

if Meteor.isClient
    tagFilter = new ReactiveArray []
    authorFilter = new ReactiveArray []
    AutoForm.addHooks 'add',
        before:
            insert: (doc) ->
                user = Meteor.user()
                doc.authorId = user._id
                doc.authorName = user.profile.name
                doc
    Accounts.ui.config
        passwordSignupFields: 'USERNAME_ONLY'
        #dropdownClasses: 'simple'
        #dropdownTransition: 'drop'
    AutoForm.debug()

    Tracker.autorun -> Meteor.subscribe 'docs', tagFilter.array()
    Tracker.autorun -> Meteor.subscribe 'tags', tagFilter.array(), authorFilter.array()
    Meteor.startup -> AutoForm.setDefaultTemplate 'semanticUI'

    Template.filter.helpers
        tags: -> Tags.find {}, sort: count: -1
        tagFilterList: -> tagFilter.list()
        authorFilterList: -> authorFilter.list()
    Template.filter.events
        'click .addCloudTagFilter':  ->
            tagFilter.push @name.toString()
        'click .removeTagFilter': -> tagFilter.remove @toString()
        'click .removeAuthorFilter': -> authorFilter.remove @toString()


    Template.docs.helpers
        docs: -> Docs.find()
        isOwner: ->  @authorId is Meteor.userId()
        isVotable: -> @authorId is not Meteor.userId()
    Template.docs.events
        'click .removeDoc': -> Meteor.call 'removeDoc', @_id
        'click .vote':  -> Meteor.call 'vote', @_id
        'click .addAuthorFilter':  ->
            console.log @authorName
            authorFilter.push @authorName
        'click .addDocFilter':  -> tagFilter.push @toString()

if Meteor.isServer
    Meteor.publish 'docs', (tagFilterArray) ->
        if tagFilterArray.length is 0 then Docs.find()
        else Docs.find tags: $all: tagFilterArray

    Meteor.publish 'tags', (tagFilterArray, authorFilterArray) ->
        self = @
        match = {}

        if tagFilterArray.length > 0 then match.tags= $all: tagFilterArray
        if authorFilterArray.length > 0 then match.authorId= $in: authorFilterArray
        console.log match
        cloud = Docs.aggregate [
            { $match: match}
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: tagFilterArray }
            { $project: _id: 0, name: '$_id', count: 1 }
        ]
        cloud.forEach (tag) -> self.added 'tags', Random.id(),
            name: tag.name
            count:tag.count



        self.ready()

    Meteor.methods
        aggUser: (userId) ->
            userCloud = Docs.aggregate [
                { $match: authorId: userId }
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $project: _id: 0, name: '$_id', count: 1 }
                ]
            Meteor.users.update {_id:userId}, {$set: {cloud: userCloud} }

            #userCloud.forEach (tag) ->
                #console.log tag
                #Meteor.users.update {_id: userId}, { $addToSet: cloud: tag }

    Docs.allow
        insert: (userId, doc) -> userId
        remove: (userId, doc) -> userId is @authorId