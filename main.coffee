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
    AutoForm.addHooks 'add',
            onSuccess: (formType, result) ->
                Meteor.call 'updateTags'
                AutoForm.resetForm add

    Meteor.subscribe 'posts'
    Meteor.subscribe 'tags'


    filter = new ReactiveArray ['Tom', 'Dick', 'Harry']
    Template.tags.helpers
        tags: -> Tags.find({}, {sort: count: -1})
        filter: -> filter.list()
    Template.tags.events
        'click .ftag': (event, template) -> filter.push @._id
        'click .button.icon': -> filter.remove @.toString()


    Template.posts.helpers
        posts: -> Posts.find()

    Meteor.startup ->
        AutoForm.setDefaultTemplate 'semanticUI'
        AutoForm.debug()



if Meteor.isServer
    Meteor.publish 'posts', -> Posts.find()
    Meteor.publish 'tags', -> Tags.find()

    #Kadira.connect 'rFvGdJvAfypbQj3uP', '998ed03e-6c4d-4e65-a529-cb9f094bb97f'
    Posts.allow
        insert: -> true
    Meteor.methods
        updateTags: ->
            Posts.aggregate([
                #{ $match: creatorId: @userId }
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                #{ $sort: count: -1 }
                { $project: _id: 1, count: 1 }
                { $out: 'tags' }
            ])

    Meteor.startup ->
