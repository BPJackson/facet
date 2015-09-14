@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'

Posts.helpers 
    authorob: -> Meteor.users.findOne username:@author

Meteor.methods
    join: (postId)->
        post = Posts.findOne postId
        me = Meteor.user().username
        
        Posts.update postId, $addToSet: joined: me
        Meteor.users.update {username: me}, $addToSet: joined: postId
                
    unjoin: (postId)->
        post = Posts.findOne postId
        me = Meteor.user().username
        
        Posts.update postId, $pull: joined: me
        Meteor.users.update {username: me}, $pull: joined: postId
            
    like: (postId)->
        post = Posts.findOne postId
        me = Meteor.user().username
        
        Meteor.users.update {username: post.author}, $inc: rating: 1
        
        Meteor.users.update {username: me}, $addToSet: liked: postId
        
        Posts.update postId, 
            $addToSet: liked: me
            $inc: rating: 1
            
    unlike: (postId)->
        post = Posts.findOne postId
        me = Meteor.user().username
        
        Meteor.users.update {username:post.author}, $inc: rating: -1
        
        Meteor.users.update {username: me}, $addToSet: liked: postId
        
        Posts.update postId, 
            $pull: liked: me
            $inc: rating: -1
            

if Meteor.isClient
    Session.setDefault 'editing', null
    
    selected = new ReactiveArray []

    Accounts.ui.config passwordSignupFields: 'USERNAME_ONLY'

    Tracker.autorun -> Meteor.subscribe 'tags', selected.array()
    Tracker.autorun -> Meteor.subscribe 'posts', selected.array(), Session.get 'editing'
    
    Meteor.subscribe 'people'

    Template.cloud.helpers
        selected: -> selected.list()
        tags: -> 
            postCount = Posts.find().count()
            if postCount > 0 then Tags.find {count: $lt: postCount} else Tags.find()
        posts: -> Posts.find {}
    
    Template.post.helpers
        editing: -> Session.equals 'editing', @_id
        editable: -> Meteor.userId() is @authorId

        titleTagClass: -> if selected.array().indexOf(@valueOf()) > -1 then 'active' else ''
        
        joinable: -> Meteor.user() and @joined.indexOf(Meteor.user().username) is -1
        unjoinable: -> if Meteor.user() and @joined.indexOf(Meteor.user().username) > -1 and @liked.indexOf(Meteor.user().username) is -1 then true else false
        
        likable: -> if Meteor.user() and @joined.indexOf(Meteor.user().username) > -1 and @liked.indexOf(Meteor.user().username) is -1 then true else false
            
        unlikable: -> if Meteor.user() and @liked.indexOf(Meteor.user().username) > -1 then true else false
    
    Template.menu.helpers 
        rating: -> Meteor.user().rating
    

    Template.cloud.events
        'click .toggleOn': -> selected.push @name.toString()
        'click .toggleOff': -> selected.remove @toString()
    
    Template.menu.events
        'click .home': -> 
            selected.clear()
            Session.set 'editing', null
        
        'click .add': ->
            newId = Posts.insert {
                author: Meteor.user().username
                joined: []
                liked: []
                }
            Session.set 'editing', newId
            selected.clear()
    
    Template.post.events
        'click .edit': (e,t)-> Session.set 'editing', @_id
        'click .titleTag': (e)->
            Session.set 'editing', null
            if selected.array().indexOf(@toString()) is -1 then selected.push @toString()
            else selected.remove @toString()
        
        'click .save': (e,t)->
            body = t.find('textarea').value
            Posts.update @_id, $set: body: body
            
            selected.clear()
            @tags.forEach (tag)-> selected.push tag
            Session.set 'editing', null

        'click .delete': ->
            Posts.remove @_id
            selected.clear()
            Session.set 'editing', null
            
        'click .like': -> Meteor.call 'like', @_id
        'click .unlike': -> Meteor.call 'unlike', @_id
        
        'click .join': -> Meteor.call 'join', @_id
        'click .unjoin': -> Meteor.call 'unjoin', @_id
            
   
    Template.edit.onRendered ->
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
    Posts.allow
        insert: (userId, post)-> post.author is Meteor.user().username
        update: (userId, post)-> post.author is Meteor.user().username
        remove: (userId, post)-> post.author is Meteor.user().username
 
    Meteor.publish 'people', -> 
        Meteor.users.find {}, fields: rating: 1, username: 1
 
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
