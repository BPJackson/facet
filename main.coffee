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
    Meteor.subscribe 'posts'
    Meteor.subscribe 'tags'

    AutoForm.addHooks 'add',
        onSuccess: (formType, result) ->
            Meteor.call 'updateTags'
            AutoForm.resetForm add


    Template.posts.helpers
        posts: -> Posts.find()
        tags: -> Tags.find()
    Meteor.startup ->
        AutoForm.setDefaultTemplate 'semanticUI'
        AutoForm.debug()



if Meteor.isServer
    Meteor.publish 'posts', -> Posts.find()
    Meteor.publish 'tags', -> Tags.find()

    Kadira.connect 'rFvGdJvAfypbQj3uP', '998ed03e-6c4d-4e65-a529-cb9f094bb97f'
    Posts.allow
        insert: -> true
    Meteor.methods
        updateTags: ->
            aggTags = Posts.aggregate([
                #{ $match: creatorId: @userId }
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $project: _id: 1, count: 1 }
                { $out: 'tags' }
            ])
            console.log 'updated tags'
            aggTags


    Meteor.startup ->
