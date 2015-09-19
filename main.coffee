@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'

FlowRouter.route '/',
    name: 'root'
    action: (params, queryParams)->
        selectedtags = queryParams.tags?.split()
        #console.log selectedtags

        #selectedtags.clear()
        BlazeLayout.render("layout", {content: "cloud"});


Posts.helpers
    author: -> Meteor.users.findOne @authorId
    bidder: -> Meteor.users.findOne @bidderId

Meteor.methods
    bid: (postId)->
        post = Posts.findOne postId

        Meteor.users.update post.bidderId, $inc: points: post.bid
        Meteor.users.update Meteor.userId(), $inc: points: -(post.bid+1)

        Posts.update postId, $set: {bidderId: Meteor.userId()}, $inc: bid: 1

    accept: (postId)->
        post = Posts.findOne postId
        Posts.update postId, $set: accepted: true
        Meteor.users.update Meteor.userId(), $inc: points: post.bid

    recommend: (postId)->
        post = Posts.findOne postId
        Posts.update postId, $set: recommended: true
        Meteor.users.update post.authorId, $inc: rating: 1

    unrecommend: (postId)->
        post = Posts.findOne postId
        Posts.update postId, $set: recommended: false
        Meteor.users.update post.authorId, $inc: rating: -1

    delete: (postId)-> Posts.remove postId

if Meteor.isClient
    selectedtags = new ReactiveArray []

    Accounts.ui.config
        passwordSignupFields: 'USERNAME_AND_OPTIONAL_EMAIL'
        dropdownClasses: 'simple'

    Template.cloud.onCreated ->
        self = @
        Session.setDefault 'editing', null
        Session.setDefault 'view', null

        #console.log FlowRouter.getQueryParam 'tags'
#
        #paramArray = FlowRouter.getQueryParam('tags')?.split ','
#
        #console.log paramArray

        #self.autorun -> Meteor.subscribe 'tags', FlowRouter.getQueryParam('tags')?.split(',')
        self.autorun -> Meteor.subscribe 'tags', selectedtags.array()
        self.autorun -> Meteor.subscribe 'posts', selectedtags.array(), Session.get('editing'), Session.get 'view'
        self.subscribe 'people'


    Template.cloud.helpers
        selectedtags: -> selectedtags.list()
        tags: -> if Posts.find().count() then Tags.find {count: $lt: Posts.find().count()} else Tags.find()
        posts: -> Posts.find {}
        user: -> Meteor.user()

    Template.post.helpers
        editing: -> Session.equals 'editing', @_id
        isAuthor: -> Meteor.userId() is @authorId

        canEdit: -> Meteor.userId() is @authorId and not @accepted and @bid is 0

        bidamount: -> if Meteor.userId() is @bidderId then 1 else @bid+1
        canBid: -> Meteor.userId() and Meteor.userId() isnt @authorId and not @accepted
        bidclass: ->
            my = Meteor.user()
            if my?
                if my._id is @authorId then 'disabled tiny'
                else if my._id is @bidderId and my.points > 0 then 'blue'
                else if my.points > @bid then 'blue'
            else 'disabled blue'

        canAccept: -> Meteor.userId() is @authorId and not @accepted and @bid > 0

        canRecommend: -> @accepted and not @recommended and Meteor.userId() is @bidderId
        canUnrecommend: -> @accepted and @recommended and Meteor.userId() is @bidderId

    Template.edit.helpers
        saveclass: -> if not @tags? then 'disabled' else ''

    Template.cloud.events
        'click #home': ->
            selectedtags.clear()
            Session.set 'editing', null
            Session.set 'view', null
            FlowRouter.setQueryParams tags: null

        'click #add': ->
            Session.set 'view', null
            selectedtags.clear()
            newId = Posts.insert {
                authorId: Meteor.userId()
                bid: 0
                bidderId: ''
                accepted: false
                }

            Session.set 'editing', newId

        'click #posts': -> Session.set 'view','posts'
        'click #bids': -> Session.set 'view','bids'
        'click #won': -> Session.set 'view','won'
        'click #toggleOn': ->
            selectedtags.push @name.toString()
            #FlowRouter.setQueryParams tags: @selectedtags.toString()
            FlowRouter.setQueryParams tags: selectedtags.join([separator = ','])
            #FlowRouter.setQueryParams tag: @name.toString()
        'click #toggleOff': ->
            selectedtags.remove @toString()
            FlowRouter.setQueryParams tags: selectedtags.join([separator = ','])

    Template.post.events
        'click #edit': (e,t)-> Session.set 'editing', @_id

        'click #save': (e,t)->
            body = t.find('textarea').value
            Posts.update @_id, $set: body: body

            selectedtags.clear()
            @tags.forEach (tag)-> selectedtags.push tag
            Session.set 'editing', null

        'click #delete': ->
            Meteor.call 'delete', @_id
            selectedtags.clear()
            Session.set 'editing', null

        'click #recommend': -> Meteor.call 'recommend', @_id

        'click #bid': -> Meteor.call 'bid', @_id

        'click #accept': -> Meteor.call 'accept', @_id

        'click #recommend': -> Meteor.call 'recommend', @_id
        'click #unrecommend': -> Meteor.call 'unrecommend', @_id

    Template.edit.onRendered ->
        $ ->
            $('#editarea').editable
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

    Meteor.publish 'people', -> Meteor.users.find {}, fields: rating: 1, username: 1, points: 1

    Meteor.publish 'posts', (selectedtags, editing, view)->
        if editing? then return Posts.find editing
        else if view?
            switch view
                when 'posts' then return Posts.find authorId: @userId
                when 'bids' then return Posts.find bidderId: @userId
                when 'won' then return Posts.find accepted: true, bidderId: @userId
        match = {}
        if selectedtags.length > 0 then match.tags= $all: selectedtags else return null
        return Posts.find match

    Meteor.publish 'tags', (selectedtags)->
        self = @
        match = {}

        if selectedtags?.length > 0 then match.tags= $all: selectedtags

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