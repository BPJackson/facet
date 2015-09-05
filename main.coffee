@Tags = new Meteor.Collection 'tags'
@Items = new Meteor.Collection 'items'

Items.helpers
    author: -> Meteor.users.findOne @authorId
    bidder: -> if @bidderId then Meteor.users.findOne @bidderId


Meteor.methods
    vote: (itemId)->
        item = Items.findOne itemId
        me = Meteor.userId()

        #if already a voter, undo vote
        if item.voters.indexOf(me) > -1
            Items.update itemId, $inc: {votes: -1}, $pull: voters: me
            Meteor.users.update item.authorId, $inc: points: -1
            return

        else #if not a voter, vote
            Items.update itemId, $inc: {votes: 1}, $addToSet: voters: me
            Meteor.users.update item.authorId, $inc: points: 1
            return

    auctionize: (itemId)->
        auction = Items.findOne itemId
        dayFromNow = Date.now() + 86400000
        Items.update itemId,
            $addToSet: tags: 'auction'
            $set: isAuction: true, auctionEnd: dayFromNow, bid: 0,


    bid: (itemId)->
        item = Items.findOne itemId

        Meteor.users.update item.bidderId, { $inc: points: item.bid }
        Meteor.users.update Meteor.userId(), { $inc: points: -(item.bid+1) }
        Meteor.users.update item.authorId, { $inc: points: 1 }

        Items.update itemId,
            $set: bidderId: Meteor.userId()
            $inc: bid: 1
        return

Items.before.insert (userId, doc) ->
    doc.timestamp = Date.now()
    doc.authorId = Meteor.userId()
    doc.voters = []
    doc.votes = 0

if Meteor.isClient
    Session.setDefault 'editing', null
    Session.setDefault 'addId', null
    selectedTags = new ReactiveArray []
    selectedAuthor = new ReactiveArray []


    Accounts.ui.config 
        dropdownClasses: 'simple'
        passwordSignupFields: 'USERNAME_ONLY'
    Tracker.autorun -> Meteor.subscribe 'tags', selectedTags.array(), selectedAuthor.array()
    Tracker.autorun -> Meteor.subscribe 'items', selectedTags.array(), selectedAuthor.array(), Session.get 'addId'

    Meteor.subscribe 'users'

    Template.home.onCreated ->
        $(window).on 'keyup', (e) ->
            #alt shift n to add
            if e.keyCode is 78 and e.shiftKey and e.altKey
                selectedTags.clear()
                selectedAuthor.clear()

                newId = Items.insert {}

                Session.set 'addId', newId
                Session.set 'editing', newId
    
    Template.home.helpers
        globalTags: ->
            itemCount = Items.find().count()
            if itemCount is 0 then Tags.find {}
            else Tags.find {count: $lt: itemCount}

        selectedTags: -> selectedTags.list()
        
        selectedAuthor: -> selectedAuthor.list()

        items: -> Items.find {}, sort: {timestamp: -1}, limit: 1

        user: -> Meteor.user()
        
        addButtonClass: -> if Session.get 'addId' then 'active' else ''
        
    Template.home.events
        'click .home': -> 
            selectedTags.clear()
            selectedAuthor.clear()
            Session.set 'addId', null
            Session.set 'editing', null
        'click .add': ->
            if Session.get 'addId' then return
            else 
                selectedTags.clear()
                selectedAuthor.clear()
    
                newId = Items.insert {}
                
                Session.set 'addId', newId
                Session.set 'editing', newId
            
        'click .selectTag': ->
            GAnalytics.event('tagSelect',@name)
            GAnalytics.pageview(@name)
            selectedTags.push @name.toString()
        
        'click .unselectTag': -> selectedTags.remove @toString()

        'click .unselectAuthor': -> selectedAuthor.remove @toString()
        'click .userCloudTag': (e)-> 
            if selectedTags.array().indexOf(@name) is -1 then selectedTags.push @name.toString()
            else selectedTags.remove @name.toString()
    Template.item.helpers
        isAuction: -> @isAuction

        isEditing: -> Session.equals 'editing', @_id

        isAuthor: -> @authorId is Meteor.userId()

        canEdit: -> Meteor.userId() is @authorId

        whenCreated: -> moment.utc(@timestamp).fromNow()

        whenEnd: -> moment.utc(@auctionEnd).fromNow()

        authorPoints: ->
            author = Meteor.users.findOne @authorId
            if author then author.points

        voteIconClass: -> if @voters.indexOf(Meteor.userId()) > -1 then 'thumbs up' else 'thumbs up outline'

        voteButtonClass: -> if not Meteor.userId() or @authorId is Meteor.userId() then 'disabled' else ''

        itemTagClass: ->
            if @valueOf() is 'auction' then ''
            else if selectedTags.array().indexOf(@valueOf()) > -1 then 'active' else ''

        authorButtonClass: ->
            if @author()
                name = @author().username
                if selectedAuthor.array().indexOf(name) > -1 then 'active' else ''

        newBid: -> @bid + 1

        canBid: ->
            userId = Meteor.userId()
            if not userId then 'disabled'
            else if @authorId is Meteor.userId() then 'disabled'
            else if Meteor.user().points < @bid then 'disabled'
            else ''


    Template.item.events
        'click .itemtag': (e)->
            Session.set 'editing', null
            if selectedTags.array().indexOf(@toString()) is -1 then selectedTags.push @toString()
            else selectedTags.remove @toString()

        'click .edit': (e,t)->
            #item = Items.findOne @_id
            #item.tags.forEach (tag) -> if selectedTags.array().indexOf(tag) is -1 then selectedTags.push tag

            Session.set 'editing', @_id

        'click .save': (e,t)->
            val = t.find('textarea').value
            Items.update @_id, $set: body: val

            item = Items.findOne @_id

            if Session.get 'addId' then item.tags.forEach (tag)-> selectedTags.push tag

            Session.set 'editing', null
            Session.set 'addId', null

        'click .username': (e)->
            if selectedAuthor.array().indexOf(@author().username) is -1 then selectedAuthor.push @author().username
            else selectedAuthor.remove @author().username

        'click .vote': ->
            Meteor.call 'vote', @_id

        'click .delete': ->
            Items.remove @_id
            selectedTags.clear()
            Session.set 'addId', null
            Session.set 'editing', null
            Meteor.call 'calcUserCloud', Meteor.userId()

        'click .bid': ->
            Meteor.call 'bid', @_id

    Template.editing.events
        'keyup input, keyup textarea':(e,t)->
            #control-c to save body input
            if (event.keyCode is 10 or event.keyCode is 13) and event.ctrlKey
                val = t.find('textarea').value
                Items.update @_id, $set: body: val

                item = Items.findOne @_id

                if Session.get 'addId' then item.tags.forEach (tag)-> selectedTags.push tag

                Session.set 'addId', null
                Session.set 'editing', null

    Template.editing.onRendered ->
        self = @
        @$('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'add tags'
            onAdd: (addedValue) ->
                switch addedValue
                    when 'delete this'
                        Items.remove self.data._id
                        Meteor.call 'calcUserCloud', Meteor.userId()
                    when 'auction'
                        Meteor.call 'auctionize', self.data._id
                        Meteor.call 'calcUserCloud', Meteor.userId()
                    else
                        Items.update self.data._id, $addToSet: tags: addedValue
                        Meteor.call 'calcUserCloud', Meteor.userId()



            onRemove: (removedValue) ->
                selectedTags.remove removedValue.toString()
                Items.update self.data._id, $pull: tags: removedValue
                Meteor.call 'calcUserCloud', Meteor.userId()

if Meteor.isServer
    Accounts.onCreateUser (options, user) ->
        user.points = 0
        user.cloud = []
        user

    Items.allow
        insert: (userId, doc)-> doc.authorId is userId
        update: (userId, doc)-> true
        remove: (userId, doc)-> doc.authorId is userId
 
    Meteor.users.allow
        insert: (userId, doc)-> true
        update: (userId, doc)-> userId
        remove: (userId, doc)-> false

    Meteor.methods
        calcUserCloud: (userId) ->
            userCloud = Items.aggregate [
                { $match: authorId: userId }
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $sort: count: -1 }
                { $project: _id: 0, name: '$_id', count: 1 }
                ]
            Meteor.users.update { _id: userId }, $set: cloud: userCloud


    Meteor.publish 'users', ->
        Meteor.users.find()

    Meteor.publish 'items', (selectedTags, selectedAuthor, addId)->
        match = {}

        if addId? then return Items.find addId

        if selectedTags.length > 0 then match.tags= $all: selectedTags else return null
        if selectedAuthor.length > 0
            author = Meteor.users.findOne username: selectedAuthor[0]
            match.authorId= author._id
        return Items.find match

    Meteor.publish 'tags', (selectedTags, selectedAuthor)->
        self = @
        match = {}

        if selectedTags.length > 0 then match.tags= $all: selectedTags

        if selectedAuthor.length > 0
            author = Meteor.users.findOne username: selectedAuthor[0]
            match.authorId= author._id


        cloud = Items.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: selectedTags }
            { $sort: count: -1 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]


        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()
