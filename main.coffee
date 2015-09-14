@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'

Posts.helpers
    author: -> Meteor.users.findOne @authorId

Meteor.methods
    bid: (postId)->
        post = Posts.findOne postId
        me = Meteor.userId()

        Meteor.users.update post.bidder, $inc: points: post.bid

        Meteor.users.update me, $inc: points: -post.bid+1

        Posts.update postId,
            $set: bidder: me
            $inc: bid: 1

    accept: (postId)->
        post = Posts.findOne postId
        me = Meteor.userId()

        Posts.update postId, $set: accepted: true

        Meteor.users.update me, $inc: points: post.bid

    recommend: (postId)->
        post = Posts.findOne postId
        me = Meteor.userId()

        #set post recommend : true
        Posts.update postId, $set: recommend: true

        #inc authors rating
        Meteor.users.update me, $inc: rating: 1

    delete: (postId)-> Post.remove postId

if Meteor.isClient
    Session.setDefault 'editing', null

    selectedtags = new ReactiveArray []

    Accounts.ui.config passwordSignupFields: 'USERNAME_AND_OPTIONAL_EMAIL'

    Tracker.autorun -> Meteor.subscribe 'tags', selectedtags.array()

    Tracker.autorun -> Meteor.subscribe 'posts', selectedtags.array(), Session.get 'editing'

    Meteor.subscribe 'people'

    Template.cloud.helpers
        selectedtags: -> selectedtags.list()

        tags: -> if Posts.find().count() then Tags.find {count: $lt: Posts.find().count()} else Tags.find()

        posts: -> Posts.find {}

    Template.post.helpers
        editing: -> Session.equals 'editing', @_id

        isAuthor: -> Meteor.userId() is @authorId

        titleTagClass: -> if @valueOf() in selectedtags.array() then 'active' else ''

        bidclass: ->
            if Meteor.userId()
                if Meteor.userId() is @bidder
                    if Meteor.user().points then ''
                else if Meteor.user().points > @bid
            else 'disabled'

        acceptable: -> @bid and Meteor.userId() is @authorId and not @accepted

        recommendable: -> Meteor.userId() is @bidder and @accepted

    Template.menu.helpers
        user: -> Meteor.user()

    Template.cloud.events
        'click .toggleOn': -> selectedtags.push @name.toString()

        'click .toggleOff': -> selectedtags.remove @toString()

    Template.menu.events
        'click .home': ->
            selectedtags.clear()
            Session.set 'editing', null

        'click .add': ->
            newId = Posts.insert {
                authorId: Meteor.userId()
                bid: 0
                bidder: ''
                accepted: false
                }

            Session.set 'editing', newId
            selectedtags.clear()

    Template.post.events
        'click .edit': (e,t)-> Session.set 'editing', @_id
        'click .titleTag': (e)->
            Session.set 'editing', null
            if @toString() not in selectedtags.array() then selectedtags.push @toString()
            else selectedtags.remove @toString()

        'click .save': (e,t)->
            body = t.find('textarea').value
            Posts.update @_id, $set: body: body

            selectedtags.clear()
            @tags.forEach (tag)-> selectedtags.push tag
            Session.set 'editing', null

        'click .delete': ->
            Meteor.call 'delete', @_id
            selectedtags.clear()
            Session.set 'editing', null

        'click .recommend': -> Meteor.call 'recommend', @_id

        'click .bid': -> Meteor.call 'bid', @_id


    Template.edit.onRendered ->
        $ ->
            $('#edit').editable
                inlineMode: false
                minHeight: 100
                toolbarFixed: false
                buttons: [
                    'bold'
                    'italic'
                    #'underline'
                    #'strikeThrough'
                    #'subscript'
                    #'superscript'
                    #'fontFamily'
                    #'fontSize'
                    #'color'
                    #'formatBlock'
                    #'blockStyle'
                    #'inlineStyle'
                    #'align'
                    #'insertOrderedList'
                    'insertUnorderedList'
                    #'outdent'
                    #'indent'
                    #'selectAll'
                    'createLink'
                    'insertImage'
                    'insertVideo'
                    #'table'
                    #'undo'
                    #'redo'
                    #'html'
                    #'save'
                    #'insertHorizontalRule'
                    #'uploadFile'
                    #'removeFormat'
                    'fullscreen'
                    ]
           return

if Meteor.isServer
    Accounts.onCreateUser (options, user)->
        user.points = 100
        user.rating = 0
        user

    Posts.allow
        insert: (userId, post)-> post.authorId is userId
        update: (userId, post)-> post.authorId is userId
        remove: (userId, post)-> post.authorId is userId

    Meteor.publish 'people', ->
        Meteor.users.find {}, fields: rating: 1, username: 1, points: 1

    Meteor.publish 'posts', (selectedtags, editing)->
        if editing? then return Posts.find editing
        match = {}
        if selectedtags.length > 0 then match.tags= $all: selectedtags else return null
        return Posts.find match

    Meteor.publish 'tags', (selectedtags)->
        self = @
        match = {}

        if selectedtags.length > 0 then match.tags= $all: selectedtags

        cloud = Posts.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: selectedtags }
            { $sort: count: -1, _id: 1 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]

        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()