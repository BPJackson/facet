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
    authorid:
        type: String
    authorname:
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
    markdown:
        type: String
        defaultValue: ' '

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
    removeDoc: (docid) -> Docs.remove docid
    vote: (docid) ->
        user = Meteor.user()
        Docs.update {
            _id: docid
            voters: $ne: user._id
        },
            $addToSet: voters: user._id
            $inc: votes: 1

        origin = Docs.findOne docid
        Docs.insert
            authorid: user._id
            authorname: user.profile.name
            tags: origin.tags


if Meteor.isClient
    tagFilter = new ReactiveArray []
    authorFilter = new ReactiveArray []
    AutoForm.addHooks 'add',
        before:
            insert: (doc) ->
                user = Meteor.user()
                doc.authorid = user._id
                doc.authorname = user.profile.name
                doc
    Accounts.ui.config
        passwordSignupFields: 'USERNAME_ONLY'
        dropdownClasses: 'simple'
    AutoForm.debug()

    Tracker.autorun -> Meteor.subscribe 'docs', tagFilter.array()
    Tracker.autorun -> Meteor.subscribe 'tagpub', tagFilter.array(), authorFilter.array()
    Meteor.startup -> AutoForm.setDefaultTemplate 'semanticUI'

    Template.filter.helpers
        tags: -> Tags.find {}, sort: count: -1
        tagFilterList: -> tagFilter.list()
        authorFilter: -> authorFilter.list()
    Template.filter.events
        'click .addCloudTagFilter':  ->
            tagFilter.push @name.toString()
        'click .removeTagFilter': -> tagFilter.remove @toString()
        'click .removeAuthorFilter': -> authorFilter.remove @toString()


    Template.docs.helpers
        docs: -> Docs.find()
        isOwner: -> Meteor.userId() is @authorid
        isVotable: -> @authorid is not Meteor.userId()
    Template.docs.events
        'click .removeDoc': -> Meteor.call 'removeDoc', @_id
        'click .vote':  -> Meteor.call 'vote', @_id
        'click .addAuthorFilter':  ->
            console.log @authorname
            authorFilter.push @authorname
        'click .addDocFilter':  -> tagFilter.push @toString()

if Meteor.isServer
    Meteor.publish 'docs', (tagFilterArray) ->
        Docs.find tags: $all: tagFilterArray
    Meteor.publish 'tagpub', (tagFilterArray, authorFilterArray) ->
        self = @
        if tagFilterArray.length is 0 and authorFilterArray.length is 0
            tags = Docs.aggregate [
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $project: _id: 1, count: 1 }
            ]
        else
            tags = Docs.aggregate [
                { $match: tags: $all: tagFilterArray }
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $match: _id: $nin: tagFilterArray }
                { $project: _id: 1, count: 1 }
            ]

        tags.forEach (tag) -> self.added 'tags', Random.id(),
            name: tag._id
            count:tag.count
        self.ready()

    Docs.allow
        insert: (userId, doc) -> userId
        remove: (userId, doc) -> userId is @authorid