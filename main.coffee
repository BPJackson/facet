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


@Tags = new Meteor.Collection 'tags'

Router.configure
    layoutTemplate: 'layout'

Router.route '/',
    name: 'root'
    template: 'posts'

if Meteor.isClient
    #AutoForm.addHooks 'add',
        #onSuccess: (formType, result) ->
            #Meteor.call 'updateTags'
            #AutoForm.resetForm add

    Meteor.subscribe 'posts'

    filter = new ReactiveArray ['food']

    Template.tags.onCreated ->
        arr = filter.array()
        Meteor.subscribe 'ragcloud', arr
    Template.tags.onRendered ->

    Template.tags.helpers
        tags: -> Tags.find {}, sort: count: -1
        filter: -> filter.list()
    Template.tags.events
        'click .ftag': (event, template) -> filter.push @._id
        'click .button.icon': -> filter.remove @.toString()

    Tracker.autorun ->
        Meteor.subscribe 'tagcloud',filter.array()

    Template.posts.helpers
        posts: ->
            if filter.array().length is 0 then Posts.find()
            else Posts.find tags: $all: filter.array()


    Meteor.startup ->
        AutoForm.setDefaultTemplate 'semanticUI'
        AutoForm.debug()



if Meteor.isServer
    Meteor.publish 'posts', -> Posts.find()
    Meteor.publish 'tagcloud', (filterArray) ->
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

    #Kadira.connect 'rFvGdJvAfypbQj3uP', '998ed03e-6c4d-4e65-a529-cb9f094bb97f'
    Posts.allow
        insert: -> true