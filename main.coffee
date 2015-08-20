@Tags = new Meteor.Collection 'tags'
@Docs = new Meteor.Collection 'docs'
Docs.attachSchema new SimpleSchema
    tags:
        type: [String]
            #selectizeOptions:
                    #plugins: ['remove_button']
                    #persist: false
                    #create: (input) ->
                        #{
                            #value: input
                            #text: input
                        #}
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
    text:
        type: String


Router.configure
    layoutTemplate: 'layout'
Router.route '/',
    name: 'root'
    template: 'docs'


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

    Meteor.subscribe 'people'
    Tracker.autorun -> Meteor.subscribe 'docs', tagFilter.array(), authorFilter.array()
    Tracker.autorun -> Meteor.subscribe 'tags', tagFilter.array(), authorFilter.array()
    Meteor.startup -> AutoForm.setDefaultTemplate 'semanticUI'

    Template.docs.helpers
        docs: -> Docs.find()
        globaltags: -> Tags.find {}, sort: count: -1
        tagFilterList: -> tagFilter.list()
        authorFilterList: -> authorFilter.list()
        personCloud: ->
            person = Meteor.users.findOne @authorId, cloud: 1
            console.log person.cloud
            debugger
            if person then person.cloud
        isOwner: ->  @authorId is Meteor.userId()
        isVotable: -> @authorId is not Meteor.userId()
    Template.docs.events
        'click .addCloudTagFilter': -> if tagFilter.indexOf(@name) is -1 then tagFilter.push @name.toString()
        'click .removeTagFilter': -> tagFilter.remove @toString()
        'click .removeAuthorFilter': -> authorFilter.remove @toString()
        'click .removeDoc': -> Meteor.call 'removeDoc', @_id
        'click .vote':  -> Meteor.call 'vote', @_id
        'click .addAuthorFilter': -> if authorFilter.indexOf(@authorName) is -1 then authorFilter.push @authorName
        'click .addDocFilter': -> tagFilter.push @toString()
        'form submit': (e,t) ->
                user = Meteor.user()
                doc.authorId = user._id
                doc.authorName = user.username
                doc


if Meteor.isServer
    Meteor.publish 'docs', (tagFilterArray, authorFilterArray) ->
        match = {}
        if tagFilterArray.length > 0 then match.tags= $all: tagFilterArray
        if authorFilterArray.length > 0 then match.authorName= $in: authorFilterArray
        Docs.find match

        #console.log match
    Meteor.publish 'tags', (tagFilterArray, authorFilterArray) ->
        self = @
        match = {}

        if tagFilterArray.length > 0 then match.tags= $all: tagFilterArray
        if authorFilterArray.length > 0 then match.authorName= $in: authorFilterArray
        cloud = Docs.aggregate [
            { $match: match }
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
    Meteor.publish 'people', -> Meteor.users.find()


    Meteor.methods
        makeUserCloud: (userId) ->
            userCloud = Docs.aggregate [
                { $match: authorId: userId }
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $sort: count: -1 }
                #{ $project: _id: 0, '$_id': '$count'}
                #{ $project: _id: 1, count: 1 }
                { $project: _id: 0, name: '$_id', count: 1 }
                ]

            Meteor.users.update {_id:userId}, $set: cloud: userCloud

    Docs.allow
        insert: (userId, doc) -> userId
        remove: (userId, doc) -> userId is @authorId