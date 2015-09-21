@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'

FlowRouter.route '/',
    name: 'root'
    action: (params, queryParams)->
        selectedtags = queryParams.tags?.split()
        #console.log selectedtags

        #selectedtags.clear()
        BlazeLayout.render("layout", {content: "home"});


Posts.helpers
    author: -> Meteor.users.findOne @authorId

Meteor.methods
    delete: (postId)-> Posts.remove postId

if Meteor.isClient
    selectedtags = new ReactiveArray []

    Accounts.ui.config
        passwordSignupFields: 'USERNAME_AND_OPTIONAL_EMAIL'
        dropdownClasses: 'simple'

    Template.home.onCreated ->
        self = @
        Session.setDefault 'editing', null
        Session.setDefault 'view', null

        #console.log FlowRouter.getQueryParam 'tags'
        #paramArray = FlowRouter.getQueryParam('tags')?.split ','
        #console.log paramArray

        #self.autorun -> Meteor.subscribe 'tags', FlowRouter.getQueryParam('tags')?.split(',')
        self.autorun -> Meteor.subscribe 'tags', selectedtags.array(), Session.get 'view', Session.get 'authorFilter'
        self.autorun -> Meteor.subscribe 'posts', selectedtags.array(), Session.get('editing'), Session.get 'view', Session.get 'authorFilter'
        self.subscribe 'people'


    Template.home.helpers
        selectedtags: -> selectedtags.list()
        tags: -> if Posts.find().count() then Tags.find {count: $lt: Posts.find().count()} else Tags.find()
        posts: -> Posts.find {}
        user: -> Meteor.user()
        toggleonclass: -> 
            switch
                when @count > 50 then 'huge'
                when @count > 40 then 'big'
                when @count > 30 then 'large'
                when @count > 20 then 'medium'
                #when @count > 10 then 'small'
                #when @count > 3 then 'tiny'
                else 'small'
                

    Template.post.helpers
        editing: -> Session.equals 'editing', @_id
        isAuthor: -> Meteor.userId() is @authorId
        postTagClass: -> if @valueOf() in selectedtags.array() then 'grey' else 'small'

    Template.home.events
        'click #home': ->
            selectedtags.clear()
            Session.set 'editing', null
            Session.set 'view', null
            Session.set 'authorFilter', null
            FlowRouter.setQueryParams tags: null

        'click #add': ->
            Session.set 'view', null
            Session.set 'authorFilter', null
            selectedtags.clear()
            newId = Posts.insert {
                authorId: Meteor.userId()
                timestamp: Date.now()
                }

            Session.set 'editing', newId

        'click #posts': -> Session.set 'view','posts'
        
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
        
        'click #clone': (e,t)-> 
            Session.set 'view', null
            Session.set 'authorFilter', null
            selectedtags.clear()
            cloneId = Posts.insert {
                authorId: Meteor.userId()
                timestamp: Date.now()
                body: @body
                tags: @tags
                }
            Session.set 'editing', cloneId
        
        'click #save': (e,t)->
            body = t.find('textarea').value
            Posts.update @_id, $set: body: body

            selectedtags.clear()
            @tags.forEach (tag)-> selectedtags.push tag
            Session.set 'editing', null

        'click #author': ->
            Session.set 'authorFilter',@authorId

        'click #delete': ->
            Meteor.call 'delete', @_id
            selectedtags.clear()
            Session.set 'editing', null
            
        'click .postTag': (e)->
            Session.set 'editing', null
            if @toString() not in selectedtags.array() then selectedtags.push @toString()
            else selectedtags.remove @toString()

    Template.edit.onRendered ->
        $ ->
            $('#editarea').editable
                inlineMode: false
                minHeight: 100
                toolbarFixed: false
                buttons: [
                    'bold'
                    'italic'
                    'underline'
                    'strikeThrough'
                    #'subscript'
                    #'superscript'
                    'fontFamily'
                    'fontSize'
                    #'color'
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
    Accounts.onCreateUser (options, user)->
        user

    Posts.allow
        insert: (userId, post)-> post.authorId is userId
        update: (userId, post)-> post.authorId is userId
        remove: (userId, post)-> post.authorId is userId

    Meteor.publish 'people', -> Meteor.users.find {}, fields: rating: 1, username: 1, points: 1

    Meteor.publish 'posts', (selectedtags, editing, view, authorFilter)->
        if editing? then return Posts.find editing
        else if view?
            switch view
                when 'posts' then return Posts.find authorId: @userId
        match = {}
        if authorFilter? then match.authorId= authorFilter
        if selectedtags.length > 0 then match.tags= $all: selectedtags else return null
        return Posts.find match

    Meteor.publish 'tags', (selectedtags, view, authorFilter)->
        self = @
        match = {}
       
        if view? then match.authorId= @userId
        if authorFilter? then match.authorId= authorFilter
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