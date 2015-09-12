@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'

Posts.helpers 
    author: -> Meteor.users.findOne @authorId

Meteor.methods
    buyPost: (postId)->
        post = Posts.findOne postId
        me = Meteor.userId()
        Meteor.users.update me, $inc: points: -post.price
        Meteor.users.update post.authorId, $inc: points: post.price
      
        Posts.update postId, 
            $set: 
                bought: true
                buyer: Meteor.userId()

if Meteor.isClient
    Session.setDefault 'editing', null
    
    selected = new ReactiveArray []

    Accounts.ui.config 
        passwordSignupFields: 'USERNAME_ONLY'
        dropdownClasses: 'simple'
        
    Tracker.autorun -> Meteor.subscribe 'tags', selected.array()
    Tracker.autorun -> Meteor.subscribe 'posts', selected.array(), Session.get 'editing'
    Meteor.subscribe 'people'

    Template.cloud.helpers
        selected: -> selected.list()
        tags: -> 
            postCount = Posts.find().count()
            if postCount > 0 then Tags.find {count: $lt: postCount} else Tags.find()
        posts: -> Posts.find {}
    
    Template.menu.helpers
        points: -> Meteor.user().points
    
    Template.cloud.events
        'click .on': -> selected.push @name.toString()
        'click .off': -> selected.remove @toString()

    Template.menu.events
        'click .home': -> 
            selected.clear()
            Session.set 'editing', null
        
        'click .add': ->
            newId = Posts.insert {
                timestamp: Date.now()
                authorId: Meteor.userId()
                price: '1'
                }
            Session.set 'editing', newId
            selected.clear()
            
    
    Template.post.helpers
        isEditing: -> Session.equals 'editing', @_id
        postTagClass: -> if selected.array().indexOf(@valueOf()) > -1 then 'active' else ''

        canEdit: -> Meteor.userId() is @authorId and not @bought
        buyButtonClass: -> if @bought then 'disabled' else '' 
            #if not Meteor.userId() and not @bought or Meteor.user().points < @price or Meteor.userId() is @authorId then 'disabled' else ''

    Template.post.events
        'click .edit': (e,t)-> Session.set 'editing', @_id
        'click .postTag': (e)->
            Session.set 'editing', null
            if selected.array().indexOf(@toString()) is -1 then selected.push @toString()
            else selected.remove @toString()
        
        'click .save': (e,t)->
            body = t.find('textarea').value
            price = t.find("input[type='number']").value
            priceInt = parseInt(price)
            Posts.update @_id, $set: body: body, price: priceInt
            
            selected.clear()
            @tags.forEach (tag)-> selected.push tag
            Session.set 'editing', null

        'click .delete': ->
            Posts.remove @_id
            selected.clear()
            Session.set 'editing', null
        
        'click .buy': -> Meteor.call 'buyPost', @_id
            
    Template.editing.onRendered ->
        $ ->
            $('#edit').editable 
                inlineMode: false
                minHeight: 100
                toolbarFixed: false
                buttons: [
                    'bold'
                    'italic'
                    'underline'
                    'strikeThrough'
                    'subscript'
                    'superscript'
                    'fontFamily'
                    'fontSize'
                    'color'
                    'formatBlock'
                    'blockStyle'
                    'inlineStyle'
                    'align'
                    'insertOrderedList'
                    'insertUnorderedList'
                    'outdent'
                    'indent'
                    'selectAll'
                    'createLink'
                    'insertImage'
                    'insertVideo'
                    'table'
                    'undo'
                    'redo'
                    'html'
                    #'save'
                    'insertHorizontalRule'
                    #'uploadFile'
                    'removeFormat'
                    'fullscreen'
                    ]
           return

if Meteor.isServer
    Accounts.onCreateUser (options, user) ->
        user.points = '10'
        user
        
    Posts.allow
        insert: (userId, post)-> post.authorId is userId
        update: (userId, post)-> post.authorId is userId
        remove: (userId, post)-> post.authorId is userId
 
    Meteor.publish 'people', -> 
        Meteor.users.find {}, fields: points: 1, username: 1
 
    Meteor.publish 'posts', (selected, editing)->
        if editing? then return Posts.find editing
        match = {}
        if selected.length > 0 then match.tags= $all: selected else return null
        return Posts.find match

    Meteor.publish 'tags', (selected)->
        self = @
        match = {}

        if selected.length > 0 then match.tags= $all: selected

        cloud = Posts.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: selected }
            { $sort: count: -1, _id: 1 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]

        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()
