class App < Jsonatra::Base

  get '/' do
    {
      hello: 'world'
    }
  end

end
