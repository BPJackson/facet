@Tags = new Meteor.Collection 'tags'
@Posts = new Meteor.Collection 'posts'

FlowRouter.route '/',
    name: 'root'
    action: (params, queryParams)->
        selectedtags = queryParams.tags?.split()
        #console.log selectedtags
        GAnalytics.pageview('/')
        #selectedtags.clear()
        BlazeLayout.render("layout", {content: "home", nav: "nav"});


Posts.helpers
    author: -> Meteor.users.findOne @authorId

Meteor.methods
    delete: (postId)-> Posts.remove postId

if Meteor.isClient
    selectedtags = new ReactiveArray []
    Session.setDefault 'editing', null
    Session.setDefault 'view', null


    AccountsTemplates.configure
        defaultLayout: 'layout'
        defaultLayoutRegions: 
            nav: 'nav'
        defaultContentRegion: 'content'

    AccountsTemplates.configureRoute 'signIn'


    pwd = AccountsTemplates.removeField('password')
    AccountsTemplates.removeField 'email'
    AccountsTemplates.addFields [
        {
            _id: 'username'
            type: 'text'
            displayName: 'username'
            required: true
            minLength: 3
        }
        pwd
    ]

    Template.nav.onCreated ->
        self = @
        self.autorun -> Meteor.subscribe 'tags', selectedtags.array(), Session.get 'authorFilter'
    
    Template.home.onCreated ->
        self = @

        #console.log FlowRouter.getQueryParam 'tags'
        #paramArray = FlowRouter.getQueryParam('tags')?.split ','
        #console.log paramArray

        #self.autorun -> Meteor.subscribe 'tags', FlowRouter.getQueryParam('tags')?.split(',')
        self.autorun -> Meteor.subscribe 'posts', selectedtags.array(), Session.get('authorFilter'), Session.get('editing')
        self.subscribe 'people'

    Template.nav.onRendered ->
        self = @
        #Tracker.afterFlush ->
        #tags = Tags.find().fetch()
        #debugger

        #console.log/ tags
        #$('.ui.search').search 
        	#source: content
        	    #searchFields: [ 'name' ]
                #minCharacters: 0
        $('.basic.segment')
            .visibility
                type   : 'fixed'
                offset : -5 
        
        $('#mainfilter').dropdown
            allowAdditions: true
            onAdd: (value) -> 
                GAnalytics.pageview(value)
                selectedtags.push value
                Meteor.setTimeout ->
                    $('.ui.dropdown').dropdown('clear')
                , 100
                #console.log @
                #debugger
            #onRemove: (value) -> selectedtags.remove value
        return

    Template.home.helpers
        #tags: -> if Posts.find().count() then Tags.find {count: $lt: Posts.find().count()} else Tags.find()
        posts: -> Posts.find {}
        user: -> Meteor.user()

    Template.post.helpers
        editing: -> Session.equals 'editing', @_id
        isAuthor: -> Meteor.userId() is @authorId
        postTagClass: -> if @valueOf() in selectedtags.array() then 'active' else 'small'
   
    Template.nav.helpers
        tags: -> Tags.find()
        selectedtags: -> selectedtags.list()
        homeclass: -> if selectedtags.array().length is 0 and not Session.get('authorFilter') and not Session.get('editing') then 'active' else ''
        mineclass: -> if Session.equals 'authorFilter', Meteor.userId() then 'active' else ''
        user: -> Meteor.user()

    Template.nav.events
        'click #home': ->
            GAnalytics.pageview('home')
            selectedtags.clear()
            Session.set 'editing', null
            Session.set 'authorFilter', null
            FlowRouter.setQueryParams tags: null
            $('.ui.dropdown').dropdown('set exactly', selectedtags.array())

        'click #add': ->
            newId = Posts.insert {
                authorId: Meteor.userId()
                timestamp: Date.now()
                }

            Session.set 'editing', newId
            #GAnalytics.pageview('add')
            Session.set 'authorFilter', null
            selectedtags.clear()
            #$('.ui.dropdown').dropdown('set exactly', selectedtags.array())

        'click #mine': -> 
            GAnalytics.pageview('mine')
            selectedtags.clear()
            $('.ui.dropdown').dropdown('set exactly', selectedtags.array())

            Session.set 'authorFilter',Meteor.userId()

        'click #logout': -> AccountsTemplates.logout()
        'click #toggleOff': ->
            selectedtags.remove @toString()
            FlowRouter.setQueryParams tags: selectedtags.join([separator = ','])


    Template.post.events
        'click #edit': (e,t)-> Session.set 'editing', @_id
        
        'click #clone': (e,t)-> 
            Session.set 'view', null
            Session.set 'authorFilter', null
            selectedtags.clear()
            $('.ui.dropdown').dropdown('set exactly', selectedtags.array())
            
            cloneId = Posts.insert {
                authorId: Meteor.userId()
                timestamp: Date.now()
                body: @body
                tags: @tags
                }
            Session.set 'editing', cloneId
        
        'click #save': (e,t)->
            body = t.find('textarea').value
            tags = $('.ui.dropdown').dropdown('get value')
            Posts.update @_id, $set: body: body, tags: tags
            Session.set 'editing', null
            
            selectedtags.clear()
            tags.forEach (tag)-> selectedtags.push tag
            Meteor.setTimeout (->
                $('.ui.dropdown').dropdown('set exactly', selectedtags.array())
            ), 500

        'click #author': ->
            Session.set 'authorFilter',@authorId

        'click #delete': ->
            Meteor.call 'delete', @_id
            selectedtags.clear()
            $('.ui.dropdown').dropdown('set exactly', selectedtags.array())

            Session.set 'editing', null
            
        'click .postTag': (e)->
            Session.set 'editing', null        
            GAnalytics.pageview(@toString())
            if @toString() not in selectedtags.array() then selectedtags.push @toString()
            else selectedtags.remove @toString()
            $('.ui.dropdown').dropdown('set exactly', selectedtags.array())

    Template.edit.onRendered ->
        self = @
        $ ->
            $('#tagselector').dropdown
                allowAdditions: true
                placeholder: 'add tags'

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
                    #'fontFamily'
                    #'fontSize'
                    #'color'
                    'formatBlock'
                    #'blockStyle'
                    #'inlineStyle'
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
        insert: (userId, post)-> post.authorId is userId
        update: (userId, post)-> post.authorId is userId
        remove: (userId, post)-> post.authorId is userId

    Meteor.publish 'people', -> Meteor.users.find {}, fields: username: 1

    Meteor.publish 'tags', (selectedtags, authorFilter)->
        self = @
        match = {}
       
        if authorFilter? then match.authorId= authorFilter
        if selectedtags?.length > 0 then match.tags= $all: selectedtags

        cloud = Posts.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: selectedtags }
            { $sort: count: -1, _id: 1 }
            { $limit: 20 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]

        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()

    Meteor.publish 'posts', (selectedtags, authorFilter, editing)->
        if editing? then return Posts.find editing
        match = {}
        if authorFilter? then match.authorId= authorFilter
        if selectedtags?.length > 0 then match.tags= $all: selectedtags else return null
        return Posts.find match, limit: 7