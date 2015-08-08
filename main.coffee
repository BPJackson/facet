@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'
Posts.attachSchema new SimpleSchema
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
        defaultValue: 0
    voters:
        type: [String]
        defaultValue: []
    submitted:
        type: Date
        defaultValue: new Date()

Router.configure
    layoutTemplate: 'layout'
Router.route '/',
    name: 'root'
    template: 'posts'

Meteor.methods
    removePost: (postid) -> Posts.remove postid
    vote: (postid) ->
        user = Meteor.user()
        Posts.update {
            _id: postid
            voters: $ne: user._id
        },
            $addToSet: voters: user._id
            $inc: votes: 1

        origin = Posts.findOne postid
        Posts.insert
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

    Meteor.subscribe 'posts'
    Tracker.autorun -> Meteor.subscribe 'tagpub',tagFilter.array()
    Meteor.startup ->
        AutoForm.setDefaultTemplate 'semanticUI'
        AutoForm.debug()




    Template.filter.helpers
        tags: -> Tags.find {}, sort: count: -1
        tagFilterList: -> tagFilter.list()
        authorFilter: -> authorFilter.list()
    Template.filter.events
        'click .addCloudTagFilter':  -> tagFilter.push @_id
        'click .removeTagFilter': -> tagFilter.remove @toString()



    Template.posts.helpers
        posts: ->
            if tagFilter.array().length is 0 then Posts.find()
            else Posts.find tags: $all: tagFilter.array()
        isOwner: -> Meteor.userId() is @authorid
        isVotable: -> Meteor.user() and @authorid is not Meteor.userId()
    Template.posts.events
        'click .removePost': -> Meteor.call 'removePost', @_id
        'click .vote':  -> Meteor.call 'vote', @_id
        'click .addAuthorFilter':  -> authorFilter.push @authorname
        'click .addPostFilter':  -> tagFilter.push @toString()



if Meteor.isServer
    Meteor.publish 'posts', -> Posts.find()
    Meteor.publish 'tagpub', (tagFilterArray) ->
        self = @
        if tagFilterArray.length is 0
            tags = Posts.aggregate [
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $project: _id: 1, count: 1 }
            ]
        else
            tags = Posts.aggregate [
                { $match: tags: $all: tagFilterArray }
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