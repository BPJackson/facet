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
Tags.attachSchema new SimpleSchema
    name:
        type: String
    count:
        type: Number

Router.configure
    layoutTemplate: 'layout'

Router.route '/',
    name: 'root'
    template: 'posts'



if Meteor.isClient
    Meteor.subscribe 'posts'
    Accounts.ui.config
        dropdownClasses: 'simple'
    Template.posts.helpers
        posts: -> Posts.find()
    Meteor.startup ->
        AutoForm.setDefaultTemplate 'semanticUI'
        AutoForm.debug()



if Meteor.isServer
    Meteor.publish 'posts', -> Posts.find()
    Kadira.connect 'rFvGdJvAfypbQj3uP', '998ed03e-6c4d-4e65-a529-cb9f094bb97f'
    Posts.allow
        insert: -> true

    Meteor.startup ->
