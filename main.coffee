@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'
Posts.attachSchema new SimpleSchema
    tags:
        type: [String]
        autoform:
            type: "selectize"
            afFieldInput:
                multiple: true
                selectizeOptions:
                    plugins: ['remove_button']
                    create: (input) ->
                        {
                            value: input
                            text: input
                        }

Router.configure
    layoutTemplate: 'layout'

Router.route '/',
    name: 'root'
    template: 'posts'

Meteor.methods
    addPost: (doc) ->
        post = _.extend doc,
            userId: user._id,
            author: user.username,
            submitted: new Date(),
            upvoters: [],
            votes: 0
    removePost: (postID) -> Posts.remove postID
    likePost: (postid) ->
        Posts.update {postid}, {$inc: likes: 1, $addtoset: voters: @.userId}
        origin = Posts.findOne postid
        Posts.insert
            userId: user._id,
            author: user.username,
            submitted: new Date(),
            upvoters: [],
            votes: 0
            tags: origin.tags


if Meteor.isClient
    filter = new ReactiveArray []
    Meteor.subscribe 'posts'
    Tracker.autorun ->
        Meteor.subscribe 'tagpub',filter.array()
    Meteor.startup ->
        AutoForm.setDefaultTemplate 'semanticUI'
        AutoForm.debug()


    Template.posts.helpers
        posts: ->
            if filter.array().length is 0 then Posts.find()
            else Posts.find tags: $all: filter.array()
        isOwner: -> true
    Template.posts.events
        'click .removePost': ->
            console.log @
            Meteor.call 'removePost', @._id
        'click .vote': (e,t) ->
            Meteor.call 'likePost'

    Template.tags.helpers
        tags: -> Tags.find {}, sort: count: -1
        filter: -> filter.list()
    Template.tags.events
        'click .ftag': (event, template) -> filter.push @._id
        'click .removeTag': -> filter.remove @.toString()

if Meteor.isServer
    Meteor.publish 'posts', -> Posts.find()
    Meteor.publish 'tagpub', (filterArray) ->
        self = @
        if filterArray.length is 0
            tags = Posts.aggregate [
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $project: _id: 1, count: 1 }
            ]
        else
            tags = Posts.aggregate [
                { $match: tags: $all: filterArray }
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $project: _id: 1, count: 1 }
            ]

        tags.forEach (e) ->
            self.added 'tags', e._id,
                    _id: e._id
                    count: e.count
        self.ready()

    Posts.allow
        insert: -> true
        remove: -> true